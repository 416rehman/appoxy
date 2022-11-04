use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::{Json, Value};
use rocket::serde::json::serde_json::json;
use crate::models::buildpack::Buildpack;
use crate::utility::stack::detect_common_stacks;

#[post("/stacks/suggest", data = "<buildpacks>")]
pub async fn common(buildpacks: Json<Vec<Buildpack>>) -> status::Custom<Value> {
    match detect_common_stacks(&buildpacks).await {
        Ok(common_stacks) => status::Custom(Status::Ok, json!({
                "message": "Common stacks detected",
                "data": {
                    "common_stacks": common_stacks
                }
            }),
        ),
        Err(err) => {
            println!("Error: {}", err);
            status::Custom(Status::BadRequest, json!({
                    "message": "Common stacks detection failed",
                    "error": err.to_string(),
                    "data": {}
                }),
            )
        }
    }
}
