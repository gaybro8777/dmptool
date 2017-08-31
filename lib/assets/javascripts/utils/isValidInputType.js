import { isString, isNumber } from './isType';
import {
  PASSWORD_MIN_LENGTH,
  PASSWORD_MAX_LENGTH } from '../constants';

/*
  Validates whether or not the value passed matches to a valid email
  @param value String to search for a match
  @return true or false
*/
export const isValidEmail = (value) => {
  if (isString(value)) {
    return /[^@\s]+@(?:[-a-z0-9]+\.)+[a-z]{2,}$/.test(value);
  }
  return false;
};

/*
  Validates whether or not the value passed is a valid number.
  @param value Number to validate
*/
export const isValidNumber = (value) => {
  if (isString(value)) { // Only if is string value we try to convert to Number
    // since Number([]), Number(new Date()), Number(null) are converted to zero
    return !isNaN(Number(value));
  }
  return isNumber(value);
};

/*
  Validates whether or not the value passed falls between the min and max length
  string specified for a password.
  @param value String to verify its length
  @return true or false
*/
export const isValidPassword = (value) => {
  if (isString(value)) {
    const trimmed = value.trim();
    return trimmed.length >= PASSWORD_MIN_LENGTH &&
    trimmed.length <= PASSWORD_MAX_LENGTH;
  }
  return false;
};

/*
  Validates whether or not the value passed is a non-empty String type.
  @param value String to verify its length
  @return true or false
*/
export const isValidText = (value) => {
  if (isString(value)) {
    return value.trim().length > 0;
  }
  return false;
};
