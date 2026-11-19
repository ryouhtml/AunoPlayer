//! Desktop TUI entrypoint for Auno Player.
//!
//! Keep this thin: all playback logic lives in `auno_player::player::Session`
//! so the exact same core can be driven by the Android JNI bridge.

use std::{io::stdout, path::PathBuf, time::Duration};

use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{backend::CrosstermBackend, Terminal};

use auno_player::{player::Session, ui::view};

const TICK: Duration = Duration::from_millis(100);

fn main() -> Result<(), Box<dyn std::error::Error>> {
    tracing_subscriber::fmt()
        .with_file(false)
        .with_line_number(false)
        .with_target(false)
        .init();

    let root = std::env::args_os()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));

    let mut session = Session::new(root, None)?;

    enable_raw_mode()?;
    let mut out = stdout();
    execute!(out, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(out);
    let mut terminal = Terminal::new(backend)?;

    let result = event_loop(&mut terminal, &mut session);

    let _ = disable_raw_mode();
    let _ = execute!(terminal.backend_mut(), LeaveAlternateScreen);
    let _ = terminal.show_cursor();
    result
}

fn event_loop(
    terminal: &mut Terminal<CrosstermBackend<std::io::Stdout>>,
    session: &mut Session,
) -> Result<(), Box<dyn std::error::Error>> {
    loop {
        session.poll_events();
        terminal.draw(|frame| view::render(frame, session))?;

        if !event::poll(TICK)? {
            continue;
        }
        let Event::Key(key) = event::read()? else {
            continue;
        };
        if key.kind != KeyEventKind::Press {
            continue;
        }

        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => break,
            KeyCode::Up => session.move_selection(-1),
            KeyCode::Down => session.move_selection(1),
            KeyCode::Enter => session.play_selected(),
            KeyCode::Char(' ') => session.toggle_pause(),
            KeyCode::Left => session.seek(-5),
            KeyCode::Right => session.seek(5),
            KeyCode::Char('-') => session.set_volume(session.volume.saturating_sub(5)),
            KeyCode::Char('+') | KeyCode::Char('=') => {
                session.set_volume(session.volume.saturating_add(5));
            }
            KeyCode::Char('b') | KeyCode::Char('B') => session.toggle_bypass(),
            KeyCode::Char('r') | KeyCode::Char('R') => session.refresh()?,
            KeyCode::Char('n') | KeyCode::Char('N') => session.next(),
            KeyCode::Char('p') | KeyCode::Char('P') => session.previous(),
            _ => {}
        }
    }
    Ok(())
}
