import { ApolloClient, InMemoryCache, gql, HttpLink } from '@apollo/client';

window.ApolloClient = ApolloClient;
window.HttpLink = HttpLink;
window.InMemoryCache = InMemoryCache;
window.gql = gql;