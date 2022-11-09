use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::{Json, Value};
use rocket::serde::json::serde_json::json;
use crate::models::droid::Droid;

#[post("/droids", data = "<droid>")]
pub async fn new(mut droid: Json<Droid>) -> status::Custom<Value> {
    match droid.detect_common_stacks().await {
        Ok(common_stacks) => {
            println!("Common stacks: {:?}", common_stacks);
            status::Custom(Status::Ok, json!({
                    "message": "Droid created",
                    "data": {
                        "droid": droid.into_inner(),
                        "common_stacks": common_stacks
                    }
                })
            )
        }
        Err(e) => {
            println!("Error: {:?}", e);
            status::Custom(Status::InternalServerError, json!({
                    "message": "droid creation failed",
                    "error": e.to_string(),
                    "data": {}
                })
            )
        }
    }
}
