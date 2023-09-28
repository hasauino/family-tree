function setRightClickMenuEventListeners(network, callback) {
    document.addEventListener('contextmenu', event => event.preventDefault());
    network.on("oncontext", rightClickListener);
    network.on("hold", holdListener);
    network.on("dragStart", removeRightClickMenu);
    network.on("zoom", removeRightClickMenu);
    document.addEventListener("click", () => { removeRightClickMenu(); })



    function rightClickListener(params) {
        const node = this.getNodeAt(params.pointer.DOM);
        if (node == null) {
            removeRightClickMenu();
            return;
        }
        if (showRightClickMenu(params)) {
            callback(node, params);
        }
    }

    function holdListener(params) {
        const node = this.getNodeAt(params.pointer.DOM);
        const canvas_dimensions = document.getElementById('tree').getBoundingClientRect();
        params.pointer.DOM = { x: canvas_dimensions.width / 2.0, y: canvas_dimensions.height / 2.0 };
        if (showRightClickMenu(params)) {
            callback(node, params);
        }
    }

    function showRightClickMenu(params) {
        const optionsElm = document.getElementById("options");
        if (optionsElm == null) { return false; }
        optionsElm.style.display = "block";
        optionsElm.style.top = `${params.pointer.DOM.y}px`;
        optionsElm.style.left = `${params.pointer.DOM.x}px`;
        return true;
    }
}

function removeRightClickMenu() {
    const optionsElm = document.getElementById("options");
    if (optionsElm == null) { return; }
    optionsElm.style.display = "none";
}

export { setRightClickMenuEventListeners };