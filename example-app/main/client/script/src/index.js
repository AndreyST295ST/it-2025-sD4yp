import { mount, el } from "../node_modules/redom/dist/redom.es";

const main = document.getElementById("main");

mount(main, <div className="my">ПРИВЕТ!</div>);
