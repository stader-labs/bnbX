export const getHours = (miliSecs: number) => {
  return parseInt((miliSecs / (1000 * 60 * 60)).toString());
};

export const getMins = (miliSecs: number) => {
  return parseInt((miliSecs / (1000 * 60)).toString());
};
