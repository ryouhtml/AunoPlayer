use std::env;
use std::path::PathBuf;

/// Cargo-ndk passes the Android sysroot to bindgen via
/// BINDGEN_EXTRA_CLANG_ARGS. Cargokit (used by flutter_rust_bridge) sets CC/AR
/// for cross builds but not those bindgen variables, so derive the same flags
/// from the compiler path here. This keeps the native bind step working for
/// both build systems.
fn ndk_prebuilt(target: &str) -> Option<PathBuf> {
    for key in [
        format!("CC_{}", target),
        format!("CC_{}", target.replace('-', "_")),
    ] {
        if let Ok(cc) = env::var(&key) {
            if let Some(prebuilt) = PathBuf::from(cc)
                .ancestors()
                .find(|p| p.file_name().and_then(|n| n.to_str()) == Some("bin"))
                .and_then(|p| p.parent())
            {
                return Some(prebuilt.to_path_buf());
            }
        }
    }
    for key in ["ANDROID_NDK_HOME", "ANDROID_NDK_ROOT", "NDK_HOME"] {
        if let Ok(ndk) = env::var(key) {
            return Some(
                PathBuf::from(ndk).join("toolchains/llvm/prebuilt/linux-x86_64"),
            );
        }
    }
    None
}

fn android_bindgen_clang_args() -> Vec<String> {
    let target = match env::var("TARGET") {
        Ok(target) => target,
        Err(_) => return Vec::new(),
    };
    if !target.ends_with("-android") {
        return Vec::new();
    }
    let sysroot_target = match target.as_str() {
        "armv7-linux-androideabi" => "arm-linux-androideabi",
        other => other,
    };
    let prebuilt = match ndk_prebuilt(&target) {
        Some(prebuilt) => prebuilt,
        None => return Vec::new(),
    };
    let sysroot = prebuilt.join("sysroot");
    vec![
        format!("--sysroot={}", sysroot.display()),
        format!(
            "-I{}",
            sysroot.join("usr/include").join(sysroot_target).display()
        ),
    ]
}

fn main() {
    let wavpack_src = PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("wavpack/src");
    let wavpack_include =
        PathBuf::from(env::var("CARGO_MANIFEST_DIR").unwrap()).join("wavpack/include");

    let decode_sources = [
        "common_utils.c",
        "decorr_utils.c",
        "entropy_utils.c",
        "open_filename.c",
        "open_legacy.c",
        "open_raw.c",
        "open_utils.c",
        "read_words.c",
        "tags.c",
        "tag_utils.c",
        "unpack.c",
        "unpack_dsd.c",
        "unpack_floats.c",
        "unpack_seek.c",
        "unpack_utils.c",
        "unpack3.c",
        "unpack3_open.c",
        "unpack3_seek.c",
        "write_words.c",
    ];

    let mut build = cc::Build::new();
    build
        .warnings(false)
        .opt_level(2)
        .define("WAVPACK_ENABLE_LEGACY", None)
        .define("ENABLE_DSD", None)
        .include(&wavpack_src)
        .include(&wavpack_include);

    for src in &decode_sources {
        build.file(wavpack_src.join(src));
    }

    build.compile("wavpack");

    let mut bindings = bindgen::Builder::default()
        .header(
            wavpack_include
                .join("wavpack.h")
                .to_str()
                .unwrap(),
        )
        .clang_arg(format!("-I{}", wavpack_include.display()))
        .clang_arg(format!("-I{}", wavpack_src.display()))
        .parse_callbacks(Box::new(bindgen::CargoCallbacks::new()))
        .allowlist_function("Wavpack.*")
        .allowlist_type("Wavpack.*")
        .allowlist_var("(OPEN_|MODE_|CONFIG_|QMODE_|BYTES_STORED|MONO_FLAG|HYBRID_FLAG|JOINT_STEREO|CROSS_DECORR|HYBRID_SHAPE|FLOAT_DATA|INT32_DATA|HYBRID_BITRATE|HYBRID_BALANCE|INITIAL_BLOCK|FINAL_BLOCK|SHIFT_LSB|SHIFT_MASK|MAG_LSB|MAG_MASK|SRATE_LSB|SRATE_MASK|FALSE_STEREO|NEW_SHAPING|HAS_CHECKSUM|DSD_FLAG|WP_FORMAT_.*|MAX_WAVPACK_SAMPLES).*")
        .no_copy("WavpackContext")
        .size_t_is_usize(true);
    for arg in android_bindgen_clang_args() {
        bindings = bindings.clang_arg(arg);
    }
    let bindings = bindings
        .generate()
        .expect("Unable to generate wavpack bindings");

    let out_path = PathBuf::from(env::var("OUT_DIR").unwrap());
    bindings
        .write_to_file(out_path.join("bindings.rs"))
        .expect("Couldn't write bindings");
}
