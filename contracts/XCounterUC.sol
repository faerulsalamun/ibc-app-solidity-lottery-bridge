//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.9;

import "./base/UniversalChanIbcApp.sol";

contract XCounterUC is UniversalChanIbcApp {
    // application specific state
    uint64 public counter;
    mapping(uint64 => address) public counterMap;

    constructor(address _middleware,address _admin) UniversalChanIbcApp(_middleware) {
        admin = _admin;
    }

    // application specific logic
    function resetCounter() internal {
        counter = 0;
    }

    function increment() internal {
        counter++;
    }

    // IBC logic

    /**
     * @dev Sends a packet with the caller's address over the universal channel.
     * @param destPortAddr The address of the destination application.
     * @param channelId The ID of the channel to send the packet to.
     * @param timeoutSeconds The timeout in seconds (relative).
     */
    function sendUniversalPacket(address destPortAddr, bytes32 channelId, uint64 timeoutSeconds) external {
        increment();
        bytes memory payload = abi.encode(msg.sender, counter);

        uint64 timeoutTimestamp = uint64((block.timestamp + timeoutSeconds) * 1000000000);

        IbcUniversalPacketSender(mw).sendUniversalPacket(
            channelId, IbcUtils.toBytes32(destPortAddr), payload, timeoutTimestamp
        );

        addToScoreboard(channelId);
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and returns and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the packet was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     */
    function onRecvUniversalPacket(bytes32 channelId, UniversalPacket calldata packet)
        external
        override
        onlyIbcMw
        returns (AckPacket memory ackPacket)
    {
        recvedPackets.push(UcPacketWithChannel(channelId, packet));

        (address payload, uint64 c) = abi.decode(packet.appData, (address, uint64));
        counterMap[c] = payload;

        increment();

        return AckPacket(true, abi.encode(counter));
    }

    /**
     * @dev Packet lifecycle callback that implements packet acknowledgment logic.
     *      MUST be overriden by the inheriting contract.
     *
     * @param channelId the ID of the channel (locally) the ack was received on.
     * @param packet the Universal packet encoded by the source and relayed by the relayer.
     * @param ack the acknowledgment packet encoded by the destination and relayed by the relayer.
     */
    function onUniversalAcknowledgement(bytes32 channelId, UniversalPacket memory packet, AckPacket calldata ack)
        external
        override
        onlyIbcMw
    {
        ackPackets.push(UcAckWithChannel(channelId, packet, ack));

        // decode the counter from the ack packet
        (uint64 _counter) = abi.decode(ack.data, (uint64));

        if (_counter != counter) {
            resetCounter();
        }
    }

    /**
     * @dev Packet lifecycle callback that implements packet receipt logic and return and acknowledgement packet.
     *      MUST be overriden by the inheriting contract.
     *      NOT SUPPORTED YET
     *
     * @param channelId the ID of the channel (locally) the timeout was submitted on.
     * @param packet the Universal packet encoded by the counterparty and relayed by the relayer
     */
    function onTimeoutUniversalPacket(bytes32 channelId, UniversalPacket calldata packet) external override onlyIbcMw {
        timeoutPackets.push(UcPacketWithChannel(channelId, packet));
        // do logic
    }

    /** Custom Logic For Bridge Lottery */
    uint256 public startTime;
    bool public isActive = false;
    uint256 public batch;
    address public admin;

    modifier onlyAdmin() {
        require(msg.sender == admin, "The caller is not admin.");
        _;
    }

    struct ScoreboardParticipants {
        address sender;
        uint256 timestamp;
    }

    struct Scoreboard {
        string channelId;
        address winner;
        ScoreboardParticipants[] participants;
    }

    mapping(uint256 => Scoreboard) public scoreboards;

    struct NetworkChannel {
        string channelName;
        string channelId;
    }

    NetworkChannel[] public networkChannels;

    function startChallenge() external onlyAdmin {
        require(!isActive, "Already start");
        require(networkChannels.length > 0 , "Please add network channel");      

        startTime = block.timestamp;
        isActive = true;

        string memory randomChannelId = shuffle();

        batch++;
        scoreboards[batch].channelId = randomChannelId;
    }

    function addToScoreboard(bytes32 _channelId) internal {
         if (isActive == true && 
            block.timestamp <= startTime + 2 hours && 
            compareStringAndBytes32(scoreboards[batch].channelId, _channelId)) {
                
            ScoreboardParticipants memory participant = ScoreboardParticipants(
                msg.sender,
                block.timestamp
            );

            scoreboards[batch].participants.push(participant);
        }
    }

    function endChallenge() external onlyAdmin {
        require(isActive, "Not start");    
        // require(block.timestamp >= startTime + 2 hours,"Not end");
  
        isActive = false;
        
        if (scoreboards[batch].participants.length != 0){
            // TO DO Integrated with Chainlink VRF
            uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, blockhash(block.number - 1)))) % scoreboards[batch].participants.length;
            
            scoreboards[batch].winner = scoreboards[batch].participants[randomNumber].sender;
        }
    }

    function addNetworkChannels(
        NetworkChannel[] calldata _networkChannels
    ) external onlyAdmin {
        for (uint256 i=0; i<_networkChannels.length; i++) {
            networkChannels.push(_networkChannels[i]);
        }
    }

    function shuffle() internal view returns(string memory) {
        // TO DO Integrated with Chainlink VRF
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, blockhash(block.number - 1)))) % networkChannels.length;
        return networkChannels[randomNumber].channelId;
    }

    function getParticipants(uint256 _batch) public view returns(ScoreboardParticipants[] memory) {
        return scoreboards[_batch].participants;
    }

    function compareStringAndBytes32(string memory str, bytes32 b32) public pure returns (bool) {
        // Convert the string to bytes32
        bytes32 strBytes32 = stringToBytes32(str);

        // Compare the two bytes32 values
        return strBytes32 == b32;
    }

    // Function to convert a string to bytes32
    function stringToBytes32(string memory str) internal pure returns (bytes32 result) {
        bytes memory tempBytes = bytes(str);
        // Limit the string to 32 bytes (or less if the string is shorter)
        require(tempBytes.length <= 32, "String too long");

        assembly {
            result := mload(add(str, 32))
        }
    }
}
