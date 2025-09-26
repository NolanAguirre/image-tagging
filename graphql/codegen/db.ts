import { Pool, Client } from 'pg'


const defaultConfig =  {
    database:process.env.DATABASE,
    host:process.env.PGHOST,
    user:process.env.PGUSER,
    password:process.env.PGPASSWORD,
    port: process.env.PGPORT || 5432,
}

const pool = (config = defaultConfig) => {
    return new Pool(config)
}

const client = (config = defaultConfig) => {
    try{
        return new Client(config)
    }catch(e){
        console.error(e)
    }
}

//very simple pg abstraction
export default {
    Pool:pool, 
    Client:client, 
    config:defaultConfig
}