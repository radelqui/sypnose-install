import { McpServer, defineTool } from '@modelcontextprotocol/sdk';
import apiClient from './api';

const kb_save = defineTool({
  name: 'kb_save',
  description: 'Save a key-value pair to the knowledge base.',
  input: {
    type: 'object',
    properties: {
      key: { type: 'string' },
      value: { type: 'string' },
      category: { type: 'string' },
      project: { type: 'string' },
    },
    required: ['key', 'value', 'project'],
  },
  run: async (input) => {
    const { key, value, category, project } = input;
    const response = await apiClient.post('/save', { key, value, category, project });
    return response.data;
  },
});

const kb_read = defineTool({
  name: 'kb_read',
  description: 'Read a value from the knowledge base by key.',
  input: {
    type: 'object',
    properties: {
      key: { type: 'string' },
      project: { type: 'string' },
    },
    required: ['key', 'project'],
  },
  run: async (input) => {
    const { key, project } = input;
    const response = await apiClient.get(`/read?key=${key}&project=${project}`);
    return response.data;
  },
});

const kb_search = defineTool({
  name: 'kb_search',
  description: 'Search the knowledge base.',
  input: {
    type: 'object',
    properties: {
      query: { type: 'string' },
      project: { type: 'string' },
      category: { type: 'string' },
      limit: { type: 'number' },
    },
    required: ['query'],
  },
  run: async (input) => {
    const { query, project, category, limit } = input;
    const response = await apiClient.get('/search', { params: { query, project, category, limit } });
    return response.data;
  },
});

const kb_list = defineTool({
  name: 'kb_list',
  description: 'List items from the knowledge base.',
  input: {
    type: 'object',
    properties: {
      project: { type: 'string' },
      category: { type: 'string' },
      limit: { type: 'number' },
      offset: { type: 'number' },
    },
    required: [],
  },
  run: async (input) => {
    const { project, category, limit, offset } = input;
    const response = await apiClient.get('/list', { params: { project, category, limit, offset } });
    return response.data;
  },
});

export { kb_save, kb_read, kb_search, kb_list };
