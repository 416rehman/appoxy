use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::{Json, Value};
use rocket::serde::json::serde_json::json;
use crate::models::droid::Droid;

#[post("/droids", data = "<droid>")]
pub async fn new(mut droid: Json<Droid>) -> status::Custom<Value> {
    match droid.detect_common_stacks().await {
        Ok(common_stacks) => {
            println!("Common stacks detected: {:?}", common_stacks);
            if !common_stacks.contains(&droid.stack.id) {
                return status::Custom(Status::BadRequest, json!({
                    "message": "The stack provided is not compatible with the buildpacks provided",
                    "data": {
                        "compatible_stacks": common_stacks
                    }
                }));
            }
        },
        Err(e) => {
            println!("Error: {:?}", e);
            return status::Custom(Status::BadRequest, json!({
                "message": "Error while detecting common stacks",
                "data": {
                    "error": e.to_string()
                }
            }))
        }
    };

    match droid.create_builder().await {
        Ok(builder) => {
            println!("Saving Builder: {:?}", builder);
            match builder.save(droid.app_id.to_string()) {
                Ok(path) => {
                    println!("Builder dumped to file: {:?}", path);
                },
                Err(e) => {
                    println!("Error: {:?}", e);
                    return status::Custom(Status::BadRequest, json!({
                        "message": "Error while dumping builder to file",
                        "data": {
                            "error": e.to_string()
                        }
                    }))
                }
            }
            status::Custom(Status::Ok, json!({
                "message": "Droid created",
                "data": {
                    "builder": builder
                }
            }))
        },
        Err(error) => {
            println!("Error creating builder: {}", error);
            status::Custom(Status::InternalServerError, json!({
                "message": "Error creating builder",
                "data": {
                    "error": error
                }
            }))
        }
    }
}
