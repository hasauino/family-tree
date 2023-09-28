const link = HttpLink({
  uri: '/graphql',
  credentials: 'same-origin'
});

const client = new ApolloClient({
  cache: new InMemoryCache(),
  link,
});

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

function editBookmark(bookmarkID, label = null, color = null, fontColor = null, fontSize = null) {
  return client.mutate({
    mutation: gql`
        mutation {
            editBookmark(id: ${bookmarkID}, fontSize: -1, label: "${label}", fontColor: "${fontColor}", color: "${color}") {
              ok
              message
            }
          }
        `
  })
}


function resetBookmark(bookmarkID) {
  return editBookmark(bookmarkID, "", "", "", -1);
}


export {
  addPerson,
  deletePerson,
  connectedNodes,
  canDelete,
  publishPerson,
  getPublishBookmarkStatus,
  unbookmarkPerson,
  unpublishPerson,
  bookmarkPerson,
  editBookmark,
  resetBookmark,
};