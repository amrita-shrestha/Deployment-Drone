"use strict";

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.getSetLocaleAsLanguageHeader = exports.getPlurals = void 0;

var _plurals = _interopRequireDefault(require("./plurals.js"));

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

var getPlurals = function getPlurals(options) {
  return options.plurals || _plurals.default;
};

exports.getPlurals = getPlurals;

var getSetLocaleAsLanguageHeader = function getSetLocaleAsLanguageHeader(options) {
  return typeof options.setLocaleAsLanguageHeader === 'boolean' ? options.setLocaleAsLanguageHeader : true;
};

exports.getSetLocaleAsLanguageHeader = getSetLocaleAsLanguageHeader;