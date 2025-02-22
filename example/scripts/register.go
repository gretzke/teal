package main

import (
	"context"
	"log"
	"log/slog"
	"os"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients/avsregistry"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/elcontracts"
	"github.com/Layr-Labs/eigensdk-go/chainio/clients/wallet"
	"github.com/Layr-Labs/eigensdk-go/chainio/txmgr"
	"github.com/Layr-Labs/eigensdk-go/logging"
	"github.com/Layr-Labs/eigensdk-go/metrics"
	rpccalls "github.com/Layr-Labs/eigensdk-go/metrics/collectors/rpc_calls"
	"github.com/Layr-Labs/eigensdk-go/signerv2"
	"github.com/Layr-Labs/eigensdk-go/types"
	"github.com/Layr-Labs/teal/example/utils"

	"github.com/Layr-Labs/eigensdk-go/chainio/clients/eth"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/urfave/cli/v2"
)

var (
	BlsPrivateKeyFlag = cli.StringFlag{
		Name:     "bls-private-key",
		Usage:    "The private key to use for the node",
		Value:    "",
		Required: true,
	}
	SocketFlag = cli.StringFlag{
		Name:     "socket",
		Usage:    "The socket to use for the node",
		Value:    "",
		Required: true,
	}
)

func main() {
	app := cli.NewApp()
	app.Name = "register-avs"
	app.Usage = "xyz"
	app.Version = "0.0.1"

	app.Flags = []cli.Flag{
		&utils.EthUrlFlag,
		&utils.EigenlayerDeploymentPathFlag,
		&utils.AvsDeploymentPathFlag,
		&utils.EcdsaPrivateKeyFlag,
		&BlsPrivateKeyFlag,
		&SocketFlag,
	}

	app.Action = start

	if err := app.Run(os.Args); err != nil {
		log.Fatal(err)
	}
}

func start(c *cli.Context) error {
	reg := prometheus.NewRegistry()
	rpcCallsCollector := rpccalls.NewCollector("exampleAvs", reg)
	client, err := eth.NewInstrumentedClient(c.String(utils.EthUrlFlag.Name), rpcCallsCollector)
	if err != nil {
		panic(err)
	}

	logger := logging.NewTextSLogger(os.Stdout, &logging.SLoggerOptions{Level: slog.LevelInfo})

	chainid, err := client.ChainID(context.Background())
	if err != nil {
		panic(err)
	}

	privateKeyString := c.String(utils.EcdsaPrivateKeyFlag.Name)
	if privateKeyString[0:2] == "0x" {
		privateKeyString = privateKeyString[2:]
	}

	ecdsaPrivateKey, err := crypto.HexToECDSA(privateKeyString)
	if err != nil {
		panic(err)
	}

	signerV2, addr, err := signerv2.SignerFromConfig(signerv2.Config{PrivateKey: ecdsaPrivateKey}, chainid)
	if err != nil {
		panic(err)
	}

	pkWallet, err := wallet.NewPrivateKeyWallet(client, signerV2, addr, logger)
	if err != nil {
		panic(err)
	}

	txManager := txmgr.NewSimpleTxManager(
		pkWallet,
		client,
		logger,
		addr,
	)

	met := metrics.NewEigenMetrics("example", "9000", reg, logger)

	elConfig, err := utils.ReadEigenlayerDeployment(c.String(utils.EigenlayerDeploymentPathFlag.Name))
	if err != nil {
		panic(err)
	}

	avsDeployment, err := utils.ReadAVSDeployment(c.String(utils.AvsDeploymentPathFlag.Name))
	if err != nil {
		panic(err)
	}

	elReader, err := elcontracts.NewReaderFromConfig(elConfig, client, logger)
	if err != nil {
		panic(err)
	}

	elWriter, err := elcontracts.NewWriterFromConfig(elConfig, client, logger, met, txManager)
	if err != nil {
		panic(err)
	}

	operator := types.Operator{
		Address:                   addr.String(),
		MetadataUrl:               "https://example.com",
		DelegationApproverAddress: "0x0000000000000000000000000000000000000000",
		AllocationDelay:           0,
	}

	isRegisteredWithEL, err := elReader.IsOperatorRegistered(context.Background(), operator)
	if err != nil {
		panic(err)
	}

	if !isRegisteredWithEL {
		reciept, err := elWriter.RegisterAsOperator(context.Background(), operator, true)
		if err != nil {
			panic(err)
		}

		if reciept.Status == 0 {
			logger.Error("Failed to register operator with EigenLayer", "receipt", reciept)
		} else {
			logger.Info("Registered operator with EigenLayer", "tx", reciept.TxHash.Hex())
		}
	}

	avsWriter, err := avsregistry.NewWriterFromConfig(
		avsDeployment.ToConfig(),
		client,
		txManager,
		logger,
	)
	if err != nil {
		panic(err)
	}

	reciept, err := avsWriter.RegisterOperator(
		context.Background(),
		ecdsaPrivateKey,
		utils.NewBlsKeyPairPanics(c.String(BlsPrivateKeyFlag.Name)),
		types.QuorumNums{0},
		c.String(SocketFlag.Name),
		true,
	)
	if err != nil {
		panic(err)
	}

	if reciept.Status == 0 {
		logger.Error("Failed to register operator with AVS", "receipt", reciept)
	} else {
		logger.Info("Registered operator with AVS", "tx", reciept.TxHash.Hex())
	}
	return nil
}
