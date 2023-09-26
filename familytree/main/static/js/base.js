function sessionSet(key, value) {
    var xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function () {
        if (this.readyState == 4 && this.status == 200) {
            return JSON.parse(this.responseText);
        }
        else {
            return null;
        }
    };
    const url = context.urls.main.sessionSet;
    xhttp.open("GET", `${url}/${key}/${value}`, true);
    xhttp.send();
}

function search() {
    if (document.getElementById("searchTxt").value == '') {
        document.getElementById("searchBox").style.display = "none";
    }
    var str_search = document.getElementById("searchTxt").value
    if (str_search.length < 2) return;
    document.getElementById("searchBox").style.display = "block";
    const xhttp = new XMLHttpRequest();
    xhttp.onreadystatechange = function () {
        if (this.readyState == 4 && this.status == 200) {
            var json = JSON.parse(this.responseText);
            document.getElementById("searchItems").innerText = '';
            for (var i = 0; i < json.parents.length; i++) {
                document.getElementById("searchItems").appendChild(create_search_item(json.parents[i], json.ids[i]));
            }
        }
    };
    const name = document.getElementById("searchTxt").value
    xhttp.open("GET", `${context.urls.main.searchByName}/${name}`, true);
    xhttp.send();
}

function create_search_item(txt, id) {
    const a = document.createElement('a');
    const textNode = document.createTextNode(txt);
    a.appendChild(textNode);
    a.setAttribute('class', 'list-group-item list-group-item-action');
    a.href = '/'.concat(id);
    return a;
}
