import axios from 'axios';
import * as dotenv from 'dotenv';

dotenv.config();

const apiClient = axios.create({
  baseURL: 'https://kb.sypnose.cloud/api',
  headers: {
    'CF-Access-Client-Id': process.env.SYPNOSE_CF_CLIENT_ID,
    'CF-Access-Client-Secret': process.env.SYPNOSE_CF_CLIENT_SECRET,
    'Content-Type': 'application/json',
  },
});

export default apiClient;
