// Library facade over the UNMODIFIED upstream sources (see Cargo.toml for why).
// Same module set as upstream src/main.rs, made pub so the fuzz harness can reach
// jless::jsonparser::parse. Each module is included by #[path] from ../../src/.
#![allow(clippy::collapsible_else_if)]
#![allow(clippy::int_plus_one)]

#[path = "../../../src/app.rs"]
pub mod app;
#[path = "../../../src/flatjson.rs"]
pub mod flatjson;
#[path = "../../../src/highlighting.rs"]
pub mod highlighting;
#[path = "../../../src/input.rs"]
pub mod input;
#[path = "../../../src/jsonparser.rs"]
pub mod jsonparser;
#[path = "../../../src/jsonstringunescaper.rs"]
pub mod jsonstringunescaper;
#[path = "../../../src/jsontokenizer.rs"]
pub mod jsontokenizer;
#[path = "../../../src/lineprinter.rs"]
pub mod lineprinter;
#[path = "../../../src/options.rs"]
pub mod options;
#[path = "../../../src/screenwriter.rs"]
pub mod screenwriter;
#[path = "../../../src/search.rs"]
pub mod search;
#[path = "../../../src/terminal.rs"]
pub mod terminal;
#[path = "../../../src/truncatedstrview.rs"]
pub mod truncatedstrview;
#[path = "../../../src/types.rs"]
pub mod types;
#[path = "../../../src/viewer.rs"]
pub mod viewer;
#[path = "../../../src/yamlparser.rs"]
pub mod yamlparser;
