#[macro_use] extern crate rocket;

#[cfg(test)] mod integration_tests;
mod routers;
mod models;
mod utility;

#[get("/")]
fn index() -> &'static str {
    "Hello, world!"
}

#[launch]
fn rocket() -> _ {
    rocket::build().mount("/", routes![index, routers::droids_router::new, routers::stacks_router::common])
}
