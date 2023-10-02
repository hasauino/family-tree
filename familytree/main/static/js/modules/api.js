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
                  title
                  font {
                    strokeWidth
                  }
                }
                children {
                  id
                  label
                  group
                  opacity
                  title
                  font {
                    strokeWidth
                  }
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
                title
                group
                opacity
                font{
                  strokeWidth
                }
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

function editBookmark(bookmarkID, label = null, color = null, fontColor = null, fSize = null) {
  if (label != null) {
    label = JSON.stringify(label);
  }
  if (color != null) {
    color = JSON.stringify(color);
  }
  if (fontColor != null) {
    fontColor = JSON.stringify(fontColor);
  }
  return client.mutate({
    mutation: gql`
        mutation {
            editBookmark(id: ${bookmarkID}, label: ${label}, fontColor: ${fontColor}, color: ${color}, fontSize: ${fSize}) {
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