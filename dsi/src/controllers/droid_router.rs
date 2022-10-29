use rocket::http::Status;
use rocket::response::status;
use rocket::serde::json::Json;
use crate::models::droid_model::Droid;

#[post("/droids", data = "<droid>")]
pub fn new(droid: Json<Droid>) -> status::Custom<Json<Droid>> {
    println!("Droid: {:?}", droid);
    status::Custom(Status::Created, droid)
}
