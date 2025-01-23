package node

import (
	"context"
	"encoding/binary"
	"fmt"
	"math/big"

	"github.com/Layr-Labs/teal/node/server"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

const (
	BnSize        = 8
)

type UvnCallNode struct {
	*server.BaseNode
	uniClient *ethclient.Client
}

func NewUvnCallNode(nodeConfig server.Config, rpcUrl string) *UvnCallNode {
	node := &UvnCallNode{}
	node.BaseNode = server.NewBaseNode(nodeConfig, node)

	uniClient, err := ethclient.Dial(rpcUrl)
	if err != nil {
		panic(err)
	}
	node.uniClient = uniClient

	return node
}

func (n *UvnCallNode) GetResponse(nodeConfig server.Config, data []byte) ([]byte, error) {
	if len(data) < BnSize {
		return nil, fmt.Errorf("data too short")
	}

	bn := binary.BigEndian.Uint64(data[:BnSize])
	
	block, err := n.uniClient.BlockByNumber(context.Background(), big.NewInt(int64(bn)))
	if err != nil {
		return nil, fmt.Errorf("failed to get block by number: %w", err)
	}

	blockHash := block.Hash().Bytes()

	return crypto.Keccak256(append(data, blockHash...)), nil
}
