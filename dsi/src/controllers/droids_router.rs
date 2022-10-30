use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::Json;
use crate::models::droid_model::Droid;

#[post("/droids", data = "<droid>")]
pub async fn new(droid: Json<Droid>) -> status::Custom<Json<Droid>> {
    let common_stacks = droid.detect_common_stacks().await;
    if let Ok(stacks) = common_stacks {
        println!("Common stacks: {:?}", stacks);
        status::Custom(Status::Ok, droid)
    } else {
        status::Custom(Status::BadRequest, droid)
    }
}
