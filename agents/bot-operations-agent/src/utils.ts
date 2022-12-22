export const getHours = (miliSecs: number) => {
  return Math.trunc(miliSecs / (1000 * 60 * 60));
};

export const getMins = (miliSecs: number) => {
  const mins = Math.trunc(miliSecs / (1000 * 60));
  return mins % 60;
};
