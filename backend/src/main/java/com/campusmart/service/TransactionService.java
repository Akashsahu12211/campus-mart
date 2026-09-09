package com.campusmart.service;

import com.campusmart.model.Item;
import com.campusmart.model.Transaction;
import com.campusmart.repository.ItemRepository;
import com.campusmart.repository.TransactionRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class TransactionService {

    @Autowired
    private TransactionRepository transactionRepository;

    @Autowired
    private ItemRepository itemRepository;

    public Transaction createTransaction(Transaction transaction) {
        Item item = transaction.getItem();
        item.setStatus(Item.ItemStatus.SOLD);
        itemRepository.save(item);
        return transactionRepository.save(transaction);
    }

    public List<Transaction> getAllTransactions() {
        return transactionRepository.findAll();
    }

    public List<Transaction> getTransactionsByBuyer(Long buyerId) {
        return transactionRepository.findByBuyerIdOrderByCreatedAtDesc(buyerId);
    }

    public List<Transaction> getTransactionsBySeller(Long sellerId) {
        return transactionRepository.findBySellerIdOrderByCreatedAtDesc(sellerId);
    }
}