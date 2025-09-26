import { gql } from 'graphql-tag'

const typeDefs = gql`
  type Query {
    hello: String
    images: [Image]
    image(id: ID!): Image
  }

  type Mutation {
    createImage(input: CreateImageInput!): Image
    updateImage(id: ID!, input: UpdateImageInput!): Image
    deleteImage(id: ID!): Boolean
  }

  type Image {
    id: ID!
    filename: String!
    url: String!
    tags: [String!]!
    createdAt: String!
    updatedAt: String!
  }

  input CreateImageInput {
    filename: String!
    url: String!
    tags: [String!]
  }

  input UpdateImageInput {
    filename: String
    url: String
    tags: [String!]
  }
`

export default typeDefs