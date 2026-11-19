use std::time::Duration;

use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph},
    Frame,
};

use crate::player::Session;

pub fn render(frame: &mut Frame, session: &Session) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),
            Constraint::Length(6),
            Constraint::Min(6),
            Constraint::Length(3),
            Constraint::Length(2),
        ])
        .split(frame.area());

    render_header(frame, chunks[0], session);
    render_tech(frame, chunks[1], session);
    render_library(frame, chunks[2], session);
    render_progress(frame, chunks[3], session);
    render_help(frame, chunks[4]);
}

fn render_header(frame: &mut Frame, area: Rect, session: &Session) {
    let state = if session.is_playing() { "PLAY" } else { "PAUSE" };
    let color = if session.is_playing() {
        Color::Green
    } else {
        Color::Yellow
    };
    let title = Line::from(vec![
        Span::styled(" AUNO ", Style::default().fg(Color::Black).bg(Color::Cyan)),
        Span::raw("  "),
        Span::styled(state, Style::default().fg(color).add_modifier(Modifier::BOLD)),
        Span::raw("  "),
        Span::raw(truncate(&session.now_playing, area.width.saturating_sub(24) as usize)),
    ]);
    frame.render_widget(
        Paragraph::new(title).block(Block::default().borders(Borders::ALL).title(" Now Playing ")),
        area,
    );
}

fn render_tech(frame: &mut Frame, area: Rect, session: &Session) {
    let (format, device) = session
        .playback
        .as_ref()
        .map(|p| (p.format.label(), p.backend.device_name().to_string()))
        .unwrap_or_else(|| ("-".into(), "-".into()));

    let bitrate = session
        .playback
        .as_ref()
        .map(|p| p.format.pcm_bytes_per_sec() * 8 / 1_000_000)
        .unwrap_or(0);

    let lines = vec![
        Line::from(vec![Span::styled("Codec/Format : ", muted()), Span::raw(format)]),
        Line::from(vec![
            Span::styled("DAC/Device   : ", muted()),
            Span::raw(device),
        ]),
        Line::from(vec![
            Span::styled("Bitrate PCM  : ", muted()),
            Span::raw(format!("{bitrate} Mb/s")),
        ]),
        Line::from(vec![
            Span::styled("Volume       : ", muted()),
            Span::raw(format!(
                "{}%  bypass={}",
                session.volume,
                if session.bypass { "ON" } else { "OFF" }
            )),
        ]),
        Line::from(vec![
            Span::styled("Buffer/Underrun: ", muted()),
            Span::raw(format!(
                "{} frames / {}",
                session.buffered_frames, session.underruns
            )),
        ]),
    ];
    frame.render_widget(
        Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title(" Technical ")),
        area,
    );
}

fn render_library(frame: &mut Frame, area: Rect, session: &Session) {
    let items: Vec<ListItem> = session
        .entries
        .iter()
        .enumerate()
        .map(|(i, entry)| {
            let style = if i == session.selected {
                Style::default()
                    .fg(Color::Black)
                    .bg(Color::Cyan)
                    .add_modifier(Modifier::BOLD)
            } else {
                Style::default()
            };
            ListItem::new(truncate(&entry.label, area.width.saturating_sub(4) as usize)).style(style)
        })
        .collect();

    frame.render_widget(
        List::new(items)
            .block(Block::default().borders(Borders::ALL).title(format!(" Library — {} ", session.root.display())))
            .highlight_style(Style::default().add_modifier(Modifier::REVERSED)),
        area,
    );
}

fn render_progress(frame: &mut Frame, area: Rect, session: &Session) {
    let ratio = if session.total.is_zero() {
        0.0
    } else {
        (session.elapsed.as_secs_f64() / session.total.as_secs_f64()).clamp(0.0, 1.0) as f64
    };
    let label = format!(
        " {} / {} ",
        format_time(session.elapsed),
        format_time(session.total)
    );
    frame.render_widget(
        Gauge::default()
            .block(Block::default().borders(Borders::ALL).title(" Position "))
            .gauge_style(Style::default().fg(Color::Cyan).bg(Color::DarkGray))
            .ratio(ratio)
            .label(label),
        area,
    );
}

fn render_help(frame: &mut Frame, area: Rect) {
    let help = "↑/↓ pilih  Enter play  Space pause  ←/→ seek±5s  -/+ volume  B bypass  R refresh  Q quit";
    frame.render_widget(
        Paragraph::new(truncate(help, area.width.saturating_sub(2) as usize))
            .style(muted())
            .block(Block::default().borders(Borders::ALL)),
        area,
    );
}

fn muted() -> Style {
    Style::default().fg(Color::DarkGray)
}

fn truncate(text: &str, max: usize) -> String {
    if text.chars().count() <= max {
        return text.to_string();
    }
    let prefix: String = text.chars().take(max.saturating_sub(1)).collect();
    format!("{prefix}…")
}

fn format_time(duration: Duration) -> String {
    let secs = duration.as_secs();
    format!("{:02}:{:02}", secs / 60, secs % 60)
}
