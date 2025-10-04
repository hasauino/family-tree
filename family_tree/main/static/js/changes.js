import { publishPerson } from "./modules/api.js";


function loaded() {
    const buttons = document.querySelectorAll('[data-person-id]');
    Array.from(buttons).forEach((button) => {
        const personId = button.dataset["personId"];
        button.onclick = () => {
            publishPerson(personId).then((result) => {
                if (result.data.publishPerson.ok) {
                    window.location.reload();
                }
                else {
                    console.error(result.data.publishPerson.ok);
                }

            }).catch((error) => {
                console.error(error);
            })
        }
    })
}

window.addEventListener('load', loaded);