//! Golden producer: use the same root serialization contract as rhwp_render_page_tree.
use rhwp::DocumentCore;
use std::{
    env, fs,
    io::{self, Write},
};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args: Vec<String> = env::args().skip(1).collect();
    if args.len() != 2 {
        return Err("usage: render_tree_golden <sample> <zero-based-page>".into());
    }
    let data = fs::read(&args[0])?;
    let page: u32 = args[1].parse()?;
    let document = DocumentCore::from_bytes(&data).map_err(|_| "document open failed")?;
    if page >= document.page_count() {
        return Err("page index out of range".into());
    }
    let tree = document
        .build_page_render_tree(page)
        .map_err(|_| "render tree producer failed")?;
    serde_json::to_writer(io::stdout().lock(), &tree.root)?;
    io::stdout().write_all(b"\n")?;
    Ok(())
}
