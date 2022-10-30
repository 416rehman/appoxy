#[macro_use] extern crate rocket;

mod services;
mod controllers;
mod models;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, controllers::droids_router::new, controllers::stacks_router::common])
}
