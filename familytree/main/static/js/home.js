import { setRightClickMenuEventListeners } from "./modules/right_click.js";
import { colorPalettes } from "./modules/tree_color_palettes.js";
import { unbookmarkPerson, resetBookmark } from "./modules/api.js";
import { deleteNode } from "./modules/vis_helpers.js";

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
        nodes: { shape: "box", font: { size: 20 }, },
        edges: {
            arrows: {
            },
            color: "#3d2414",
            smooth: {
                type: "cubicBezier",
                forceDirection: "vertical",
                roundness: 1.0,
            },
        },
        groups: colorPalettes.greenish,
        layout: {
            hierarchical: {
                direction: "DU",
                sortMethod: "directed",
                shakeTowards: 'roots',
                levelSeparation: 100,
                nodeSpacing: 10,
            },
        },
        physics: true,
    };
    var container = document.getElementById('tree');
    var network = new vis.Network(container, data, options);
    document.addEventListener('contextmenu', event => event.preventDefault());
    network.on("click", clickListener);
    setRightClickMenuEventListeners(network, handleRightClick)

    function clickListener(params) {
        if (params.nodes.length < 1) { return; }
        window.location.href = `${context.urls.main.personTree}/${params.nodes[0]}`;
    }
    function handleRightClick(node_id, params) {
        const optionsElm = document.getElementById("options");
        const buttons = optionsElm.children[0].children;
        // Edit button
        if (buttons["editBtn"]) {
            buttons["editBtn"].onclick = () => {
                window.location = `${context.urls.main.edit}/${node_id}/${currentPersonID}`;
            };
        }
        // Remove Bookmark
        buttons["unBookmarkBtn"].onclick = () => {
            unbookmarkPerson(node_id);
            deleteNode(network, node_id);
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