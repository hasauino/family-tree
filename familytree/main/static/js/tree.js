import { setRightClickMenuEventListeners } from "./modules/right_click.js";
import {
    addPerson,
    deletePerson,
    connectedNodes,
    canDelete,
    publishPerson,
    getPublishBookmarkStatus,
    unbookmarkPerson,
    unpublishPerson,
    bookmarkPerson,
} from "./modules/api.js";
import { colorPalettes } from "./modules/tree_color_palettes.js";
import { addNode, deleteNode, addEdge } from "./modules/vis_helpers.js";

function draw() {
    const data = {
        nodes: nodes,
        edges: edges,
    };
    const options = {
        interaction: {
            dragNodes: true,
            hover: true,
        },
        nodes: { shape: "box", font: { size: 20 }, },
        edges: {
            arrows: {
                to: {
                    enabled: true,
                    scaleFactor: 0.3
                },
            },
            color: "rgb(0,0,0)",
            smooth: {
                type: "cubicBezier",
                forceDirection: "vertical",
                roundness: 0.4,
            },
        },
        groups: colorPalettes.african,
        layout: {
            hierarchical: {
                direction: "UD",
                sortMethod: "directed",
                shakeTowards: 'roots',
                levelSeparation: 70,
                nodeSpacing: 150,
            },
        },
        physics: false,
    };
    var container = document.getElementById('tree');
    var network = new vis.Network(container, data, options);
    network.focus(currentPersonID, {
        scale: 1.0,
        animation: {
            duration: 500,
            easingFunction: "easeInOutCubic"
        },
    });
    network.on("doubleClick", doubleClickListener);
    network.on("click", clickListener);
    setRightClickMenuEventListeners(network, handleRightClick);


    function clickListener(params) {
        if (params.nodes.length < 1) {
            return;
        }

        connectedNodes(params.nodes[0]).then((result) => {
            const children = result.data.connectedNodes.children;
            const parent = result.data.connectedNodes.parent;
            children.forEach(node => {
                addNode(nodes, node.id, node.label, node.group, node.opacity);
                addEdge(edges, params.nodes[0], node.id);
            });
            addNode(nodes, parent.id, parent.label, parent.group, parent.opacity);
            addEdge(edges, parent.id, params.nodes[0]);
            network.focus(params.nodes[0], {
                scale: 1.0,
                animation: {
                    duration: 500,
                    easingFunction: "easeInOutCubic"
                },
            });
        }).catch((error) => {
            console.error(error);
        });
    }

    function doubleClickListener(params) {
        if (params.nodes.length < 1) { return; }
        window.location.href = `${context.urls.main.personTree}/${params.nodes[0]}`;
    }



    function handleRightClick(node_id, params) {
        const optionsElm = document.getElementById("options");
        const buttons = optionsElm.children[0].children;
        // Add child button
        buttons["addChildBtn"].onclick = () => {
            const modal = document.getElementById("addChildModal");
            modal.style.display = "block";
            const addChildButton = document.getElementById("addChildButton");
            addChildButton.onclick = () => {
                const addChildInput = document.getElementById("addChildInput");
                const childName = addChildInput.value;
                modal.style.display = "none";
                addPerson(node_id, childName).then((result) => {
                    if (!result.data.addPerson.ok) {
                        console.error(result.data.addPerson.message);
                        return;
                    }
                    const newNode = result.data.addPerson;
                    addNode(nodes, newNode.id, newNode.label, newNode.group, newNode.opacity);
                    addEdge(edges, node_id, newNode.id);
                }).catch((error) => { console.error(error); })
            }

        }
        // Delete button
        canDelete(node_id).then(
            (result) => {
                if (buttons["deleteBtn"]) {
                    buttons["deleteBtn"].disabled = !result.data.canDelete;
                    buttons["deleteBtn"].onclick = () => {
                        const modal = document.getElementById("confirmModal");
                        modal.style.display = "block";
                        const confirmButton = document.getElementById("confirmButton");
                        confirmButton.onclick = () => {
                            modal.style.display = "none";
                            deletePerson(node_id).then((result) => {
                                if (result.data.deletePerson.ok) {
                                    deleteNode(network, node_id);
                                }
                                else {
                                    console.error(result.data.deletePerson.message)
                                }
                            }).catch((error) => { console.error(error); })
                        }
                    };
                }
            }
        ).catch((error) => { console.error(error); });
        // Edit button
        if (buttons["editBtn"]) {
            buttons["editBtn"].onclick = () => {
                window.location = `${context.urls.main.edit}/${node_id}/${currentPersonID}`;
            };
        }
        // Publish and bookmark buttons
        if (buttons["publishBtn"] == null) {
            return;
        }
        var is_published = false;
        var is_bookmarked = false;
        getPublishBookmarkStatus(node_id).then(
            (result) => {
                is_published = result.data.person.published;
                is_bookmarked = result.data.person.bookmarked;
                if (is_published) {
                    buttons["publishBtn"].style.display = "none";
                    buttons["unPublishBtn"].style.display = "inline";
                    buttons["unPublishBtn"].onclick = () => {
                        unpublishPerson(node_id).then(
                            (result) => {
                                nodes.update({ id: node_id, opacity: 0.3 });
                            }
                        ).catch((error) => { console.error(error); });
                    }
                    if (is_bookmarked) {
                        buttons["bookmarkBtn"].style.display = "none";
                        buttons["unBookmarkBtn"].style.display = "inline";
                        buttons["unBookmarkBtn"].onclick = () => {
                            unbookmarkPerson(node_id);
                        }
                    }
                    else {
                        buttons["unBookmarkBtn"].style.display = "none";
                        buttons["bookmarkBtn"].style.display = "inline";
                        buttons["bookmarkBtn"].onclick = () => {
                            bookmarkPerson(node_id);
                        }
                    }
                }
                else {
                    buttons["unPublishBtn"].style.display = "none";
                    buttons["unBookmarkBtn"].style.display = "none";
                    buttons["bookmarkBtn"].style.display = "none";
                    buttons["publishBtn"].style.display = "inline";
                    buttons["publishBtn"].onclick = () => {
                        publishPerson(node_id).then(
                            (result) => {
                                nodes.update({ id: node_id, opacity: 1.0 });
                            }
                        ).catch((error) => { console.error(error); });
                    }
                }
            }
        ).catch((error) => { console.error(error) });
    }
}

window.addEventListener('load', draw);