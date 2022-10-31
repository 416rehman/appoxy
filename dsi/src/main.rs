#[macro_use] extern crate rocket;
use std::io;
use std::io::{Error, ErrorKind};
use rocket::response::stream::ReaderStream;
use rocket::tokio::io::BufReader;

#[cfg(test)] mod integration_tests;
mod routers;
mod models;
mod utility;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

/// Streams the output of a command as a response.
/// Use "curl -N" to stream the output.
#[get("/stream")]
fn stream() -> io::Result<ReaderStream![BufReader<tokio::process::ChildStdout>]> {
    let stdout = tokio::process::Command::new("ls")
        .arg("-la")
        .stdout(std::process::Stdio::piped())
        .spawn()?
        .stdout
        .take()
        .ok_or_else(|| Error::new(ErrorKind::Other,"Could not capture standard output."))?;

    let reader = BufReader::new(stdout);
    Ok(ReaderStream::one(reader))
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, routers::droids_router::new, routers::stacks_router::common, hello])
}
