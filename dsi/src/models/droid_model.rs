use rocket::serde::{Deserialize, Serialize};

#[derive(Debug)]
#[derive(Deserialize)]
#[derive(Serialize)]
#[serde(crate = "rocket::serde")]
pub struct Droid {
    app_id: i64,
    repo: String,
    branch: String,
    buildpacks: Vec<String>,
    env: Vec<String>,
}
