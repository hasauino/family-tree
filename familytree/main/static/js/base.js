function search() {
    if (document.getElementById("searchTxt").value == '') {
        document.getElementById("searchBox").style.display = "none";
    }
    var str_search = document.getElementById("searchTxt").value
    if (str_search.length < 2) return;
    document.getElementById("searchBox").style.display = "block";
    fetch('/graphql', {
        method: 'POST',
        credentials: 'same-origin',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            query: `query { searchPersons(query: ${JSON.stringify(str_search)}) { id name } }`
        })
    })
        .then(response => response.json())
        .then(({ data }) => {
            document.getElementById("searchItems").innerText = '';
            for (const person of data.searchPersons) {
                document.getElementById("searchItems").appendChild(create_search_item(person.name, person.id));
            }
        });
}

function create_search_item(txt, id) {
    const a = document.createElement('a');
    const textNode = document.createTextNode(txt);
    a.appendChild(textNode);
    a.setAttribute('class', 'list-group-item list-group-item-action');
    a.href = '/'.concat(id);
    return a;
}
