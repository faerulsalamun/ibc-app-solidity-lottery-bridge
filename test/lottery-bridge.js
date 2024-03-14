const { expect } = require("chai");
const {ethers} = require('hardhat');


describe('Test Contract', () => {
    beforeEach(async () => {
      const XCounterUC = await ethers.getContractFactory('XCounterUC');
      [owner, addr1, addr2, addr3, ...addrs] = await ethers.getSigners();

      xCounterUC = await XCounterUC.deploy(owner.address,owner.address);  
    });

    describe('Challenge', () => {
        it('should flow challenge correctly', async () => {
       
         await xCounterUC.connect(owner).addNetworkChannels([{
            channelName:"OP",
            channelId:"channel-16"
          },
          {
            channelName:"BASE",
            channelId:"channel-17"
          }]);

          await xCounterUC.connect(owner).startChallenge();

          // await xCounterUC.connect(addr1).addToScoreboard();
          // await xCounterUC.connect(addr1).addToScoreboard();
          // await xCounterUC.connect(addr2).addToScoreboard();
          // await xCounterUC.connect(addr3).addToScoreboard();

          await xCounterUC.connect(owner).endChallenge();

          let networkChannels = await xCounterUC.scoreboards(1);
          console.log(networkChannels)

          // console.log(ethers.encodeBytes32String('channel-16'));
    
        });
    });
    
    
});
