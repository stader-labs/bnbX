(async () => {
  try {
    const client = new BncClient("https://api.binance.org/bc/");
    // const client = new BncClient("https://dex-atlantic.binance.org");
    await client.initChain(56);
    const balance = await client.getTxs(
      "bnb1xgnms7dsnydz6zjr9na9rv2sz7aw3ydhacg7wc",
      1653762060000,
      1654539735365
    );
    console.log(balance);
  } catch (e) {
    console.log(e);
    // Deal with the fact the chain failed
  }
  // `text` is not available here
})();
