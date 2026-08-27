'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const zlib = require('zlib');

const outputPath = process.argv[2];
const maxBytes = Number(process.argv[3]);
const inputPath = process.argv[4];
const trainPaths = process.argv.slice(5);
const zstdDictPath = process.env.DCZ_DICT || '';
const validationLevel = Number(process.env.DCB_VALIDATION_LEVEL || 6);

if (!outputPath || !maxBytes || !inputPath || trainPaths.length === 0) {
  console.error(
    'Usage: prepare-dcb-dict.js <output.dict> <maxBytes> <input-for-validation> <train-file> [...]'
  );
  process.exit(1);
}

const input = fs.readFileSync(inputPath);

function truncate(buffer) {
  return buffer.subarray(0, maxBytes);
}

function buildCandidates() {
  const candidates = [];

  for (const trainPath of trainPaths) {
    candidates.push({
      name: `training-file:${path.basename(trainPath)}`,
      data: truncate(fs.readFileSync(trainPath)),
    });
  }

  if (trainPaths.length > 1) {
    candidates.push({
      name: 'combined-training-files',
      data: truncate(Buffer.concat(trainPaths.map((trainPath) => fs.readFileSync(trainPath)))),
    });
  }

  if (zstdDictPath && fs.existsSync(zstdDictPath)) {
    candidates.push({
      name: 'zstd-dictionary-reuse',
      data: truncate(fs.readFileSync(zstdDictPath)),
    });
  }

  return candidates;
}

function measureWithZlib(data, dictionary, level) {
  const plain = zlib.brotliCompressSync(data, {
    params: { [zlib.constants.BROTLI_PARAM_QUALITY]: level },
  }).length;

  const compressed = zlib.brotliCompressSync(data, {
    dictionary,
    params: { [zlib.constants.BROTLI_PARAM_QUALITY]: level },
  }).length;

  if (compressed < plain) {
    return compressed;
  }

  return null;
}

function makeTempDir(prefix) {
  const roots = [process.env.TMPDIR, os.tmpdir(), '/tmp'].filter(Boolean);

  for (const root of roots) {
    try {
      fs.mkdirSync(root, { recursive: true });
      return fs.mkdtempSync(path.join(root, prefix));
    } catch {
      continue;
    }
  }

  throw new Error('Could not create temporary directory for brotli validation');
}

function measureWithBrotliCli(data, dictionary, level) {
  const tmpDir = makeTempDir('dcb-dict-');
  const dictPath = path.join(tmpDir, 'dict');
  const inputFile = path.join(tmpDir, 'input');

  try {
    fs.writeFileSync(dictPath, dictionary);
    fs.writeFileSync(inputFile, data);

    const compressed = execFileSync(
      'brotli',
      ['-q', String(level), '-D', dictPath, '-c', inputFile],
      { encoding: 'buffer' }
    );

    return compressed.length;
  } finally {
    fs.rmSync(tmpDir, { force: true, recursive: true });
  }
}

function measureCompressedSize(data, dictionary, level) {
  const withZlib = measureWithZlib(data, dictionary, level);
  if (withZlib !== null) {
    return { size: withZlib, method: 'node-zlib' };
  }

  return {
    size: measureWithBrotliCli(data, dictionary, level),
    method: 'brotli-cli',
  };
}

const candidates = buildCandidates();
let best = null;

for (const candidate of candidates) {
  const result = measureCompressedSize(input, candidate.data, validationLevel);

  console.error(
    `  candidate ${candidate.name}: dict=${candidate.data.length} bytes, ` +
      `compressed=${result.size} bytes (${result.method})`
  );

  if (!best || result.size < best.compressedSize) {
    best = {
      ...candidate,
      compressedSize: result.size,
      validationMethod: result.method,
    };
  }
}

if (!best) {
  console.error('No dictionary candidates available');
  process.exit(1);
}

fs.mkdirSync(path.dirname(outputPath), { recursive: true });
fs.writeFileSync(outputPath, best.data);

console.error(
  `Selected ${best.name}: dictionary=${best.data.length} bytes, ` +
    `validation compressed=${best.compressedSize} bytes (${best.validationMethod})`
);
