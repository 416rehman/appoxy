use rocket::serde::{Deserialize, Serialize};
use crate::utility::stack::detect_common_stacks;

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

impl Droid {
    pub async fn detect_common_stacks(&self) -> Result<Vec<String>, String> {
        detect_common_stacks(&self.buildpacks).await
    }
}
