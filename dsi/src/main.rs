#[macro_use] extern crate rocket;

mod controllers;
mod config;
mod models;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, controllers::droid_router::new])
}
