import { setRightClickMenuEventListeners } from "./modules/right_click.js";
import { colorPalettes } from "./modules/tree_color_palettes.js";

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
    }
}

window.addEventListener('load', draw);