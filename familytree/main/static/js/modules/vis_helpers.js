function addNode(nodes, id, label, title, group, opacity, font) {
    try {
        nodes.add({
            id: id,
            label: label,
            group: group,
            opacity: opacity,
            title: title,
            font: font,
        });
    } catch (err) {
    }
}

function deleteNode(network, node_id) {
    network.selectNodes([node_id]);
    network.deleteSelected();
}

function addEdge(edges, from_id, to_id) {
    try {
        edges.add({
            id: to_id,
            from: from_id,
            to: to_id,
        });
    } catch (err) {
    }
}


export { addNode, deleteNode, addEdge }