export interface Image {
  id: string
  filename: string
  url: string
  tags: string[]
  createdAt: string
  updatedAt: string
}

export interface CreateImageInput {
  filename: string
  url: string
  tags?: string[]
}

export interface UpdateImageInput {
  filename?: string
  url?: string
  tags?: string[]
}