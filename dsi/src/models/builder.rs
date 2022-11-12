use std::fs::File;
use std::io::{BufRead, BufReader, Write};
use std::thread;
use rocket::serde::{Deserialize, Serialize};
use crate::models::buildpack::Buildpack;
use crate::models::order::Order;
use crate::models::stack::Stack;

// https://buildpacks.io/docs/reference/config/builder-config
#[derive(Default, Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
#[serde(crate = "rocket::serde")]
pub struct Builder {
    pub description: Option<String>,
    pub stack: Stack,
    pub buildpacks: Vec<Buildpack>,
    pub order: Vec<Order>,
}

impl Builder {
    /// Creates a builder.toml file and returns the path to the file
    pub fn save(&self, app_id: String) -> Result<String, Box<dyn std::error::Error>> {
        let save_path = format!("./dumps/{}/builder.toml", app_id);
        std::fs::create_dir_all(format!("./dumps/{}", app_id))?;
        let mut file = File::create(&save_path)?;
        file.write_all(toml::to_string(self)?.as_bytes())?;
        Ok(save_path)
    }

    // Runs "pack builder create <app_id>:<stack.id> --config /app/<app_id>/builder.toml" and return handle to the process
    pub async fn run_create<T: 'static + Send + Fn(&str)>(&self, app_id: i64, cb: T) {
        match std::process::Command::new("pack")
            .arg("builder")
            .arg("create")
            .arg(format!("{}:{}", app_id, self.stack.id))
            .arg("--config")
            .arg(format!("/app/{}/builder.toml", app_id))
            .stdout(std::process::Stdio::piped())
            .stderr(std::process::Stdio::piped())
            .spawn() {
            Ok(child) => {
                thread::spawn(move || {
                    let mut f = BufReader::new(child.stdout.unwrap());
                    loop {
                        let mut buf = String::new();
                        match f.read_line(&mut buf) {
                            Ok(_) => {
                                cb(buf.as_str());
                            }
                            Err(e) => println!("an error!: {:?}", e),
                        }
                    }
                });
            }
            Err(e) => cb(e.to_string().as_str()),
        }
    }
}
