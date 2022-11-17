#[macro_use] extern crate rocket;
use std::io;
use std::io::{Error, ErrorKind};
use std::sync::Mutex;
use rocket::response::stream::ReaderStream;
use rocket::tokio::io::BufReader;

#[cfg(test)] mod integration_tests;
mod routers;
mod models;
mod utility;

struct MyConfig {
    user_val: Mutex<String>,
}

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

/// Streams the output of a command as a response.
/// Use "curl -N" to stream the output.
#[get("/stream")]
fn stream() -> io::Result<ReaderStream![BufReader<tokio::process::ChildStdout>]> {
    let stdout = tokio::process::Command::new("journalctl")
        .arg("-f")
        .stdout(std::process::Stdio::piped())
        .spawn()?
        .stdout
        .take()
        .ok_or_else(|| Error::new(ErrorKind::Other,"Could not capture standard output."))?;

    let reader = BufReader::new(stdout);
    Ok(ReaderStream::one(reader))
}

#[get("/state?<name>")]
fn state(name: String, config: &rocket::State<MyConfig>) -> String {
    let myconfig: &MyConfig = config.inner();
    let mut lock = myconfig.user_val.lock().unwrap();
    let old_val = lock.to_string();
    *lock = name;
    format!("Hello, {}! I remember you! You were {}", lock.to_string(), old_val)
}

#[rocket::main]
async fn main() -> Result<(), rocket::Error> {
    let _rocket = rocket::build()
        .manage(MyConfig {
            user_val: Mutex::new("default".to_string()),
        })
        .mount("/", routes![index, stream, state])
        .mount("/droids", routes![routers::droids_router::new])
        .mount("/stacks", routes![routers::stacks_router::common])
        .launch()
        .await?;

    Ok(())
}