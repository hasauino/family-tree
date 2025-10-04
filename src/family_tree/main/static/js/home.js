import { setRightClickMenuEventListeners } from "./modules/right_click.js";
import { colorPalettes } from "./modules/tree_color_palettes.js";
import { unbookmarkPerson, resetBookmark, editBookmark } from "./modules/api.js";

function draw() {

    const data = {
        nodes: nodes,
        edges: edges,
    };
    const options = {
        interaction: {
            dragNodes: false,
            hover: true,
        },
        nodes: { shape: "box", font: { size: 25 }, margin: 15, },
        edges: {
            arrows: {
            },
            color: "#000000",
            smooth: {
                type: "cubicBezier",
                forceDirection: "vertical",
                roundness: 0.7,
            },
        },
        layout: {
            hierarchical: {
                direction: "DU",
                sortMethod: "directed",
                shakeTowards: 'roots',
                levelSeparation: 200,
                nodeSpacing: 350,
            },
        },
        physics: false,
    };
    var container = document.getElementById('tree');
    var network = new vis.Network(container, data, options);
    document.addEventListener('contextmenu', event => event.preventDefault());
    network.on("click", clickListener);
    setRightClickMenuEventListeners(network, handleRightClick)

    network.fit({
        minZoomLevel: 0.5,
        maxZoomLevel: 1.0,
        animation: {
            duration: 1000,
            easingFunction: "easeInOutCubic"
        },
    });

    function clickListener(params) {
        if (params.nodes.length < 1) { return; }
        window.location.href = `${context.urls.main.personTree}/${params.nodes[0]}`;
    }
    function handleRightClick(node_id) {
        const optionsElm = document.getElementById("options");
        const buttons = optionsElm.children[0].children;
        // Edit button
        if (buttons["editBtn"]) {
            buttons["editBtn"].onclick = () => {
                const modal = document.getElementById("EditBookmarkModal");
                modal.style.display = "block";
                const bookmarkModalSaveBtn = document.getElementById("bookmarkModalSaveBtn");
                bookmarkModalSaveBtn.onclick = () => {
                    const labelElm = document.getElementById("bookmarkModalLabel");
                    const colorElm = document.getElementById("bookmarkModalColor");
                    const fontSizeElm = document.getElementById("bookmarkModalFontSize");
                    const fontColorElm = document.getElementById("bookmarkModalFontColor");
                    let label = labelElm.value === "" ? null : labelElm.value;
                    let color = colorElm.value === "" ? null : colorElm.value;
                    let fontColor = fontColorElm.value === "" ? null : fontColorElm.value;
                    let fontSize = fontSizeElm.value;
                    if (fontSize === "") {
                        fontSize = null;
                    }
                    editBookmark(node_id, label, color, fontColor, fontSize).then(
                        (result) => {
                            if (result.data.editBookmark.ok) {
                                window.location = "/";
                            }
                            else {
                                console.error(result.data.editBookmark.message);
                            }
                        }
                    ).catch(
                        (error) => {
                            console.error(error);
                            modal.style.display = "none";
                        }
                    );
                }
            };
        }
        // Remove Bookmark
        buttons["unBookmarkBtn"].onclick = () => {
            unbookmarkPerson(node_id).then((result) => {
                if (result.data.unbookmarkPerson.ok) {
                    window.location.reload();
                }
                else {
                    console.error(result.data.unbookmarkPerson.message);
                }
            }).catch((error) => {
                console.error(error);
            });

        }
        // Reset Button
        buttons["resetBtn"].onclick = () => {
            resetBookmark(node_id).then((result) => {
                if (result.data.editBookmark.ok) {
                    window.location = "/";
                }
                else {
                    console.error(result.data.editBookmark.message);
                }
            }).catch((error) => { console.error(error); });
        }
    }
}

window.addEventListener('load', draw);