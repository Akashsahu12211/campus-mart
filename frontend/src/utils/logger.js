import { DEBUG_LOGS_ENABLED } from '../config/runtimeConfig';

const runIfEnabled = (fn, args) => {
  if (DEBUG_LOGS_ENABLED) {
    fn(...args);
  }
};

export const logger = {
  debug: (...args) => runIfEnabled(console.log, args),
  info: (...args) => runIfEnabled(console.info, args),
  warn: (...args) => runIfEnabled(console.warn, args),
  error: (...args) => runIfEnabled(console.error, args),
};
