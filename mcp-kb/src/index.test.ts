import apiClient from './api';

// Mock the API client
jest.mock('./api');
const mockedApiClient = apiClient as jest.Mocked<typeof apiClient>;

// We need to import the actual tools to test them
import { kb_save, kb_read, kb_search, kb_list } from './index';

describe('MCP-KB Tools', () => {
  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('kb_save', () => {
    it('should save a key-value pair', async () => {
      mockedApiClient.post.mockResolvedValue({ data: { success: true } });
      const result = await kb_save.run({
        key: 'test_key',
        value: 'test_value',
        category: 'test_category',
        project: 'test_project',
      });
      expect(result).toEqual({ success: true });
      expect(mockedApiClient.post).toHaveBeenCalledWith('/save', {
        key: 'test_key',
        value: 'test_value',
        category: 'test_category',
        project: 'test_project',
      });
    });
  });

  describe('kb_read', () => {
    it('should read a value by key', async () => {
      mockedApiClient.get.mockResolvedValue({
        data: { key: 'test_key', value: 'test_value' },
      });
      const result = await kb_read.run({
        key: 'test_key',
        project: 'test_project',
      });
      expect(result).toEqual({ key: 'test_key', value: 'test_value' });
      expect(mockedApiClient.get).toHaveBeenCalledWith(
        '/read?key=test_key&project=test_project'
      );
    });
  });

  describe('kb_search', () => {
    it('should search the knowledge base', async () => {
      mockedApiClient.get.mockResolvedValue({ data: [{ score: 0.9, value: 'test_value' }] });
      const result = await kb_search.run({
        query: 'test query',
        project: 'test_project',
        category: 'test_category',
        limit: 10,
      });
      expect(result).toEqual([{ score: 0.9, value: 'test_value' }]);
      expect(mockedApiClient.get).toHaveBeenCalledWith('/search', {
        params: {
          query: 'test query',
          project: 'test_project',
          category: 'test_category',
          limit: 10,
        },
      });
    });
  });

  describe('kb_list', () => {
    it('should list items from the knowledge base', async () => {
      mockedApiClient.get.mockResolvedValue({ data: [{ key: 'test_key', value: 'test_value' }] });
      const result = await kb_list.run({
        project: 'test_project',
        category: 'test_category',
        limit: 10,
        offset: 5,
      });
      expect(result).toEqual([{ key: 'test_key', value: 'test_value' }]);
      expect(mockedApiClient.get).toHaveBeenCalledWith('/list', {
        params: {
          project: 'test_project',
          category: 'test_category',
          limit: 10,
          offset: 5,
        },
      });
    });
  });
});
