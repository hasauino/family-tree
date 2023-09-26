function draw() {
    const link = HttpLink({
        uri: '/graphql',
        credentials: 'same-origin'
    });

    const client = new ApolloClient({
        cache: new InMemoryCache(),
        link,
    });

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
        groups: colorPalettes.modern,
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
    document.addEventListener('contextmenu', event => event.preventDefault());
    network.on("doubleClick", doubleClickListener);
    network.on("click", clickListener);
    network.on("oncontext", canvasRightClickListener);
    network.on("hold", holdListener);
    network.on("dragStart", removeRightClickMenu);
    network.on("zoom", removeRightClickMenu);


    function clickListener(params) {
        removeRightClickMenu();
        if (params.nodes.length < 1) {
            return;
        }

        connectedNodes(params.nodes[0]).then((result) => {
            const children = result.data.connectedNodes.children;
            const parent = result.data.connectedNodes.parent;
            children.forEach(node => {
                addNode(node.id, node.label, node.group, node.opacity);
                addEdge(params.nodes[0], node.id);
            });
            addNode(parent.id, parent.label, parent.group, parent.opacity);
            addEdge(parent.id, params.nodes[0]);
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

    function canvasRightClickListener(params) {
        const node = this.getNodeAt(params.pointer.DOM);
        if (node == null) {
            removeRightClickMenu();
            return;
        }
        showRightClickMenu(node, params);
    }

    function holdListener(params) {
        const node = this.getNodeAt(params.pointer.DOM);
        const canvas_dimensions = document.getElementById('tree').getBoundingClientRect();
        params.pointer.DOM = { x: canvas_dimensions.width / 2.0, y: canvas_dimensions.height / 2.0 };
        showRightClickMenu(node, params);
    }

    function addNode(id, label, group, opacity) {
        try {
            nodes.add({
                id: id,
                label: label,
                group: group,
                opacity: opacity,
            });
        } catch (err) {
        }
    }

    function addEdge(from_id, to_id) {
        try {
            edges.add({
                id: to_id,
                from: from_id,
                to: to_id,
            });
        } catch (err) {
        }
    }

    function showRightClickMenu(node_id, params) {
        const optionsElm = document.getElementById("options");
        if (optionsElm == null) { return; }
        optionsElm.style.display = "block";
        optionsElm.style.top = `${params.pointer.DOM.y}px`;
        optionsElm.style.left = `${params.pointer.DOM.x}px`;
        const buttons = optionsElm.children[0].children;
        // Add child button
        buttons["addChildBtn"].onclick = () => {
            removeRightClickMenu();
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
                    addNode(newNode.id, newNode.label, newNode.group, newNode.opacity);
                    addEdge(node_id, newNode.id);
                }).catch((error) => { console.error(error); })
            }

        }
        // Delete button
        canDelete(node_id).then(
            (result) => {
                if (buttons["deleteBtn"]) {
                    buttons["deleteBtn"].disabled = !result.data.canDelete;
                    buttons["deleteBtn"].onclick = () => {
                        removeRightClickMenu();
                        network.selectNodes([node_id]);
                        const modal = document.getElementById("confirmModal");
                        modal.style.display = "block";
                        const confirmButton = document.getElementById("confirmButton");
                        confirmButton.onclick = () => {
                            modal.style.display = "none";
                            deletePerson(node_id).then((result) => {
                                if (result.data.deletePerson.ok) {
                                    network.deleteSelected();
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
                        removeRightClickMenu();
                    }
                }
                else {
                    buttons["unPublishBtn"].style.display = "none";
                    buttons["publishBtn"].style.display = "inline";
                    buttons["publishBtn"].onclick = () => {
                        publishPerson(node_id).then(
                            (result) => {
                                nodes.update({ id: node_id, opacity: 1.0 });
                            }
                        ).catch((error) => { console.error(error); });
                        removeRightClickMenu();
                    }
                }
                if (is_bookmarked) {
                    buttons["bookmarkBtn"].style.display = "none";
                    buttons["unBookmarkBtn"].style.display = "inline";
                    buttons["unBookmarkBtn"].onclick = () => {
                        unbookmarkPerson(node_id);
                        removeRightClickMenu();
                    }
                }
                else {
                    buttons["unBookmarkBtn"].style.display = "none";
                    buttons["bookmarkBtn"].style.display = "inline";
                    buttons["bookmarkBtn"].onclick = () => {
                        bookmarkPerson(node_id);
                        removeRightClickMenu();
                    }
                }
            }
        ).catch((error) => { console.error(error) });
    }

    function removeRightClickMenu() {
        const optionsElm = document.getElementById("options");
        if (optionsElm == null) { return; }
        optionsElm.style.display = "none";
    }

    function connectedNodes(personID) {
        return client.query({
            // Query
            query: gql`
            query {
                connectedNodes(id: ${personID}) {
                    parent {
                      id
                      label
                      group
                      opacity
                    }
                    children {
                      id
                      label
                      group
                      opacity
                    }
                  }
              }
            `,
            fetchPolicy: 'no-cache'
        })
    }
    function addPerson(personID, childName) {
        return client.mutate({
            mutation: gql`
            mutation {
                addPerson(id: ${personID}, childName: \"${childName}\") {
                    id
                    label
                    group
                    opacity
                    ok
                    message
                }
              }
            `
        })
    }

    function canDelete(personID) {
        return client.query({
            // Query
            query: gql`
            query {
                canDelete(id: ${personID})
              }
            `,
            fetchPolicy: 'no-cache'
        })
    }

    function deletePerson(personID) {
        return client.mutate({
            mutation: gql`
            mutation {
                deletePerson(id: ${personID}) {
                  ok
                  message
                }
              }
            `
        })
    }

    function getPublishBookmarkStatus(personID) {
        return client.query({
            // Query
            query: gql`
            query {
                person(id: ${personID}){
                    published
                    bookmarked
                }
              }
            `,
            fetchPolicy: 'no-cache'
        })
    }

    function publishPerson(personID) {
        return client.mutate({
            mutation: gql`
            mutation {
                publishPerson(id: ${personID}) {
                  ok
                  message
                }
              }
            `
        })
    }

    function unpublishPerson(personID) {
        return client.mutate({
            mutation: gql`
            mutation {
                unpublishPerson(id: ${personID}) {
                  ok
                  message
                }
              }
            `
        })
    }

    function bookmarkPerson(personID) {
        return client.mutate({
            mutation: gql`
            mutation {
                bookmarkPerson(id: ${personID}) {
                  ok
                  message
                }
              }
            `
        })
    }
    function unbookmarkPerson(personID) {
        return client.mutate({
            mutation: gql`
            mutation {
                unbookmarkPerson(id: ${personID}) {
                  ok
                  message
                }
              }
            `
        })
    }
}



window.addEventListener('load', draw);