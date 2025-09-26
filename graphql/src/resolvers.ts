import { Image } from './types'

// Mock data for development
const images: Image[] = [
  {
    id: '1',
    filename: 'sample1.jpg',
    url: 'https://example.com/sample1.jpg',
    tags: ['nature', 'landscape'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
  {
    id: '2',
    filename: 'sample2.jpg',
    url: 'https://example.com/sample2.jpg',
    tags: ['portrait', 'people'],
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
  },
]

const resolvers = {
  Query: {
    hello: () => 'Hello from GraphQL server!',
    
    images: () => images,
    
    image: (_: any, { id }: { id: string }) => {
      return images.find(img => img.id === id)
    },
  },

  Mutation: {
    createImage: (_: any, { input }: { input: any }) => {
      const newImage: Image = {
        id: String(images.length + 1),
        filename: input.filename,
        url: input.url,
        tags: input.tags || [],
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      }
      images.push(newImage)
      return newImage
    },

    updateImage: (_: any, { id, input }: { id: string; input: any }) => {
      const imageIndex = images.findIndex(img => img.id === id)
      if (imageIndex === -1) {
        throw new Error('Image not found')
      }

      const updatedImage = {
        ...images[imageIndex],
        ...input,
        updatedAt: new Date().toISOString(),
      }
      images[imageIndex] = updatedImage
      return updatedImage
    },

    deleteImage: (_: any, { id }: { id: string }) => {
      const imageIndex = images.findIndex(img => img.id === id)
      if (imageIndex === -1) {
        return false
      }
      images.splice(imageIndex, 1)
      return true
    },
  },
}

export default resolvers