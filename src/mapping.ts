import { TransferSingle, TransferBatch } from "../generated/AdrianGallery1155/AdrianGallery1155";
import { Transfer, Holder, TokenBalance } from "../generated/schema";
import { BigInt, Address } from "@graphprotocol/graph-ts";

// Función para obtener o crear un Holder a partir de una dirección.
function getOrCreateHolder(address: Address): Holder {
  let holder = Holder.load(address.toHex());
  if (holder == null) {
    holder = new Holder(address.toHex());
    holder.address = address;
    // tokenBalances se maneja de forma derivada, no hay que inicializarla aquí.
    holder.save();
  }
  return holder;
}

// Función para obtener o crear un TokenBalance para un holder y un token específico.
function getOrCreateTokenBalance(holder: Holder, tokenId: BigInt): TokenBalance {
  let balanceId = holder.id + "-" + tokenId.toString();
  let tokenBalance = TokenBalance.load(balanceId);
  if (tokenBalance == null) {
    tokenBalance = new TokenBalance(balanceId);
    tokenBalance.tokenId = tokenId;
    tokenBalance.holder = holder;
    tokenBalance.balance = BigInt.fromI32(0);
  }
  return tokenBalance;
}

// Función para actualizar el balance de un TokenBalance.
function updateTokenBalance(holder: Holder, tokenId: BigInt, value: BigInt, increase: boolean): void {
  let tokenBalance = getOrCreateTokenBalance(holder, tokenId);
  if (increase) {
    tokenBalance.balance = tokenBalance.balance.plus(value);
  } else {
    tokenBalance.balance = tokenBalance.balance.minus(value);
  }
  tokenBalance.save();
}

export function handleTransferSingle(event: TransferSingle): void {
  let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString();
  
  // Crear la entidad Transfer para indexar el evento
  let transfer = new Transfer(id);
  transfer.from = event.params.from;
  transfer.to = event.params.to;
  transfer.tokenId = event.params.id;
  transfer.value = event.params.value;
  transfer.timestamp = event.block.timestamp;
  transfer.save();

  // Actualizar balances:
  let fromHolder = getOrCreateHolder(event.params.from);
  let toHolder = getOrCreateHolder(event.params.to);

  // Disminuir el balance del emisor
  updateTokenBalance(fromHolder, event.params.id, event.params.value, false);
  // Aumentar el balance del receptor
  updateTokenBalance(toHolder, event.params.id, event.params.value, true);
}

export function handleTransferBatch(event: TransferBatch): void {
  for (let i = 0; i < event.params.ids.length; i++) {
    let id = event.transaction.hash.toHex() + "-" + event.logIndex.toString() + "-" + i.toString();
    
    let transfer = new Transfer(id);
    transfer.from = event.params.from;
    transfer.to = event.params.to;
    transfer.tokenId = event.params.ids[i];
    transfer.value = event.params.values[i];
    transfer.timestamp = event.block.timestamp;
    transfer.save();

    let fromHolder = getOrCreateHolder(event.params.from);
    let toHolder = getOrCreateHolder(event.params.to);

    updateTokenBalance(fromHolder, event.params.ids[i], event.params.values[i], false);
    updateTokenBalance(toHolder, event.params.ids[i], event.params.values[i], true);
  }
}
