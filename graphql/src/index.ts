import { ApolloServer } from '@apollo/server'
import { startStandaloneServer } from '@apollo/server/standalone'
import typeDefs from './schema'
import resolvers from './resolvers'
import db from '../codegen/db'




const PORT = process.env.PORT || 4000
const NODE_ENV = process.env.NODE_ENV || 'development'

const server = new ApolloServer({
  typeDefs,
  resolvers,
})

const startServer = async () => {
  const { url } = await startStandaloneServer(server, {
    listen: { port: Number(PORT) },
  })

  console.log(`🚀 Server ready at: ${url}`)
  console.log(`Environment: ${NODE_ENV}`)
}

startServer().catch((error) => {
  console.error('Error starting server:', error)
  process.exit(1)
})