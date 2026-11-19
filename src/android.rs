//! JNI bridge used by the Android app (`System.loadLibrary("auno_player")`).
//!
//! The Rust core is identical to the desktop build; this module only converts
//! JNI calls into `Session` method calls and serialises state back to Kotlin
//! as small JSON strings (parsed with Android's built-in `org.json`).
//!
//! `extern "system"` functions must never unwind into the JVM, so every
//! fallible step is handled explicitly and the global mutex is recovered on
//! poisoning.

use std::{
    ffi::c_void,
    path::PathBuf,
    sync::{atomic::{AtomicBool, Ordering}, Mutex, MutexGuard},
};

use jni::{
    objects::{JClass, JObject, JString},
    sys::{jboolean, jint},
    JNIEnv,
};

use crate::player::Session;

/// One session for the whole app process. `Session: Send` (cpal Stream is
/// Send), so `Mutex<Option<Session>>` is Sync and can live in a static.
static SESSION: Mutex<Option<Session>> = Mutex::new(None);
static NDK_CONTEXT_INITIALIZED: AtomicBool = AtomicBool::new(false);

fn lock_session() -> MutexGuard<'static, Option<Session>> {
    SESSION.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

/// Initialise the JNI-side state that cpal's AAudio backend needs.
///
/// cpal 0.18 calls `ndk_context::android_context()` when it opens an output
/// stream (to read `aaudio.mixer_bursts` via `android.os.SystemProperties`).
/// Without this call that lookup panics on the audio thread. The `Context`
/// passed in from Kotlin is kept alive with a leaked global reference for the
/// lifetime of the process, which is exactly what ndk-glue does for native
/// activities.
fn ensure_android_context(env: &mut JNIEnv<'_>, context: &JObject<'_>) -> Result<(), String> {
    if NDK_CONTEXT_INITIALIZED.swap(true, Ordering::SeqCst) {
        return Ok(());
    }

    let vm = env.get_java_vm().map_err(|e| format!("GetJavaVM: {e}"))?;
    let global = env.new_global_ref(context).map_err(|e| format!("global ref: {e}"))?;
    let vm_ptr = vm.get_java_vm_pointer() as *mut c_void;
    let ctx_ptr = global.as_raw() as *mut c_void;

    // Keep the global reference alive forever; Android releases it when the
    // process dies, which matches the lifetime of SESSION and the audio stream.
    std::mem::forget(global);

    // SAFETY: both pointers come from live JNI handles owned by this process,
    // and this runs exactly once before any cpal stream is opened.
    unsafe { ndk_context::initialize_android_context(vm_ptr, ctx_ptr) };
    Ok(())
}

fn throw(env: &mut JNIEnv<'_>, message: &str) {
    let _ = env.throw_new("java/lang/RuntimeException", message);
}

fn read_jstring(env: &mut JNIEnv<'_>, value: &JString<'_>) -> Option<String> {
    match env.get_string(value) {
        Ok(chars) => Some(std::borrow::Cow::<str>::from(&*chars).into_owned()),
        Err(err) => {
            throw(env, &format!("get_string: {err}"));
            None
        }
    }
}

fn return_jstring(env: &mut JNIEnv<'_>, value: String) -> jni::sys::jstring {
    match env.new_string(value) {
        Ok(string) => string.into_raw(),
        Err(err) => {
            throw(env, &format!("new_string: {err}"));
            std::ptr::null_mut()
        }
    }
}

// ---------------------------------------------------------------------------
// Kotlin-facing API
// ---------------------------------------------------------------------------

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_init<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
    context: JObject<'local>,
    root: JString<'local>,
) -> jboolean {
    if let Err(err) = ensure_android_context(&mut env, &context) {
        throw(&mut env, &err);
        return 0;
    }
    let Some(root_path) = read_jstring(&mut env, &root) else {
        return 0;
    };

    match Session::new(PathBuf::from(root_path), None) {
        Ok(session) => {
            *lock_session() = Some(session);
            1
        }
        Err(err) => {
            throw(&mut env, &err.to_string());
            0
        }
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_poll<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Some(session) = lock_session().as_mut() {
        session.poll_events();
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_refresh<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jni::sys::jstring {
    let message = match lock_session().as_mut() {
        Some(session) => match session.refresh() {
            Ok(()) => session.status.clone(),
            Err(err) => format!("ERROR: {err}"),
        },
        None => "not initialised".into(),
    };
    return_jstring(&mut env, message)
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_play<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Some(session) = lock_session().as_mut() {
        session.play_selected();
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_pause<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Some(session) = lock_session().as_mut() {
        session.toggle_pause();
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_next<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Some(session) = lock_session().as_mut() {
        session.next();
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_previous<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) {
    if let Some(session) = lock_session().as_mut() {
        session.previous();
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_select<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
    index: jint,
) {
    if index < 0 {
        return;
    }
    if let Some(session) = lock_session().as_mut() {
        if (index as usize) < session.entries.len() {
            session.selected = index as usize;
        }
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_seek<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
    delta_ms: jint,
) {
    if let Some(session) = lock_session().as_mut() {
        session.seek(i64::from(delta_ms) / 1000);
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_setVolume<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
    volume: jint,
) {
    if let Some(session) = lock_session().as_mut() {
        session.set_volume(volume.clamp(0, 100) as u8);
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_toggleBypass<'local>(
    _env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jboolean {
    match lock_session().as_mut() {
        Some(session) => {
            session.toggle_bypass();
            jboolean::from(session.bypass)
        }
        None => 0,
    }
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_statusJson<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jni::sys::jstring {
    let json = lock_session()
        .as_ref()
        .map(status_json)
        .unwrap_or_else(|| "{\"error\":\"not initialised\"}".into());
    return_jstring(&mut env, json)
}

#[unsafe(no_mangle)]
pub extern "system" fn Java_com_aunoplayer_auno_NativeLib_libraryJson<'local>(
    mut env: JNIEnv<'local>,
    _class: JClass<'local>,
) -> jni::sys::jstring {
    let json = lock_session()
        .as_ref()
        .map(library_json)
        .unwrap_or_else(|| "[]".into());
    return_jstring(&mut env, json)
}

// ---------------------------------------------------------------------------
// Minimal JSON serialisation (no serde dependency in the audio binary)
// ---------------------------------------------------------------------------

fn json_string(value: &str) -> String {
    let mut out = String::with_capacity(value.len() + 2);
    out.push('"');
    for ch in value.chars() {
        match ch {
            '"' => out.push_str("\\\""),
            '\\' => out.push_str("\\\\"),
            '\n' => out.push_str("\\n"),
            '\r' => out.push_str("\\r"),
            '\t' => out.push_str("\\t"),
            c if c < '\u{20}' => out.push_str(&format!("\\u{:04x}", c as u32)),
            c => out.push(c),
        }
    }
    out.push('"');
    out
}

fn status_json(session: &Session) -> String {
    let (codec, device) = session
        .playback
        .as_ref()
        .map(|p| (p.format.label(), p.backend.device_name().to_string()))
        .unwrap_or_else(|| ("-".into(), "-".into()));
    let (sample_rate, bits, channels, pcm_kbps) = session
        .playback
        .as_ref()
        .map(|p| {
            (
                p.format.sample_rate,
                p.format.bits_per_sample,
                p.format.channels,
                p.format.pcm_bytes_per_sec() * 8 / 1000,
            )
        })
        .unwrap_or((0, 0, 0, 0));
    let count = session.entries.len();
    format!(
        concat!(
            "{{\"playing\":{},\"status\":{},\"now\":{},",
            "\"codec\":{},\"device\":{},",
            "\"sample_rate\":{},\"bits\":{},\"channels\":{},\"pcm_kbps\":{},",
            "\"elapsed_ms\":{},\"total_ms\":{},",
            "\"volume\":{},\"bypass\":{},\"count\":{},",
            "\"selected\":{},\"underruns\":{},\"buffered_frames\":{}}}"
        ),
        session.is_playing(),
        json_string(&session.status),
        json_string(&session.now_playing),
        json_string(&codec),
        json_string(&device),
        sample_rate,
        bits,
        channels,
        pcm_kbps,
        session.elapsed.as_millis(),
        session.total.as_millis(),
        session.volume,
        session.bypass,
        count,
        session.selected,
        session.underruns,
        session.buffered_frames,
    )
}

fn library_json(session: &Session) -> String {
    let entries = session
        .entries
        .iter()
        .map(|entry| json_string(&entry.label))
        .collect::<Vec<_>>()
        .join(",");
    format!("[{entries}]")
}
