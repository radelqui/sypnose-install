
const { exec } = require('child_process');

const runGraphify = (command) => {
  return new Promise((resolve, reject) => {
    const env = {
      ...process.env,
      GRAPHIFY_OPENAI_MODEL: 'gemini-2.5-pro',
      OPENAI_BASE_URL: 'gemini-proxy GCloud',
      OPENAI_API_KEY: 'sk-dummy'
    };

    exec(command, { env }, (error, stdout, stderr) => {
      if (error) {
        console.error(`exec error: ${error}`);
        return reject(error);
      }
      if (stderr) {
        console.error(`stderr: ${stderr}`);
      }
      resolve(stdout);
    });
  });
};

const graphify_extract = {
  name: 'graphify_extract',
  description: 'Extracts a knowledge graph from a file.',
  run: async ({ path }) => {
    return await runGraphify(`graphify extract ${path}`);
  }
};

const graphify_query = {
  name: 'graphify_query',
  description: 'Queries a knowledge graph.',
  run: async ({ question, graph_path, budget }) => {
    return await runGraphify(`graphify query --question \"${question}\" --graph-path ${graph_path} --budget ${budget}`);
  }
};

const graphify_path = {
  name: 'graphify_path',
  description: 'Finds the path between two nodes in a knowledge graph.',
  run: async ({ nodeA, nodeB, graph_path }) => {
    return await runGraphify(`graphify path --nodes ${nodeA} ${nodeB} --graph-path ${graph_path}`);
  }
};

const graphify_explain = {
  name: 'graphify_explain',
  description: 'Explains a node in a knowledge graph.',
  run: async ({ node, graph_path }) => {
    return await runGraphify(`graphify explain --node ${node} --graph-path ${graph_path}`);
  }
};

const graphify_list_graphs = {
  name: 'graphify_list_graphs',
  description: 'Lists all available knowledge graphs.',
  run: async () => {
    return await runGraphify('graphify list');
  }
};

module.exports = {
  graphify_extract,
  graphify_query,
  graphify_path,
  graphify_explain,
  graphify_list_graphs
};
