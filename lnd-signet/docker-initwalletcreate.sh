add_unlock_to_conf()
{
  echo "wallet-unlock-password-file=/root/.lnd/unlock.password" >> /root/.lnd/lnd.conf
}

echo "[lnd_unlock] Waiting 2 seconds for lnd..."
sleep 2

echo "waiting for wallet create phase"
while
    if grep -q 'lncli create' /root/.lnd/logs/bitcoin/signet/lnd.log;
    then
        echo "ready to create...."
        #Need to run the python gRPC HERE
        break;
    else
        sleep 2;
        echo "waiting to create."
    fi
do true; done

#once we get here we will want to change lnd.conf with wallet-unlock-file stuff

 MACAROON_HEADER="Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /root/.lnd/data/chain/bitcoin/simnet/admin.macaroon)"
   curl -X GET --cacert /root/.lnd/tls.cert https://localhost:8080/v1/genseed | jq .cipher_seed_mnemonic | tr -d '\n'| tr -d ' ' > /root/.lnd/seeds.txt
 # { 
 #   "cipher_seed_mnemonic": <array string>, 
 #   "enciphered_seed": <byte>, 
 # }
 # cat seeds.txt | jq .cipher_seed_mnemonic | tr -d '\n'
#password is 12345678
curl -X POST --cacert /root/.lnd/tls.cert --header  https://localhost:8080/v1/initwallet  \
    -d '{ "wallet_password":"MTIzNDU2NzgK","cipher_seed_mnemonic":"${cat seeds.txt}"}' 

#this is likely not needed anymore
# ensure that lnd is up and running before proceeding
while
    CA_CERT="/root/.lnd/data/tls.cert"
    LND_WALLET_DIR="/root/.lnd/data/chain/bitcoin/signet/"
    MACAROON_FILE="$LND_WALLET_DIR/admin.macaroon"
    MACAROON_HEADER="r0ckstar:dev"
    if [ -f "$MACAROON_FILE" ]; then
        MACAROON_HEADER="Grpc-Metadata-macaroon:$(xxd -p -c 10000 "$MACAROON_FILE" | tr -d ' ')"
    fi

    STATUS_CODE=$(curl -s --cacert "$CA_CERT" -H $MACAROON_HEADER -o /dev/null -w "%{http_code}" $LND_REST_LISTEN_HOST/v1/getinfo)
    # if lnd is running it'll either return 200 if unlocked (noseedbackup=1) or 404 if it needs initialization/unlock
    if [ "$STATUS_CODE" == "200" ] || [ "$STATUS_CODE" == "404" ] ; then
        break
    else    
        echo "[lnd_unlock] LND still didn't start, got $STATUS_CODE status code back... waiting another 2 seconds..."
        sleep 2
    fi
do true; done
 