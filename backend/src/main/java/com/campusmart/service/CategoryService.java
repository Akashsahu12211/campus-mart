package com.campusmart.service;

import com.campusmart.model.Category;
import com.campusmart.repository.CategoryRepository;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import java.util.List;

@Service
public class CategoryService {

    @Autowired
    private CategoryRepository categoryRepository;

    @Cacheable("publicCategories")
    public List<Category> getAllCategories() {
        return categoryRepository.findAll();
    }

    @CacheEvict(value = "publicCategories", allEntries = true)
    public Category addCategory(Category category) {
        return categoryRepository.save(category);
    }

    @CacheEvict(value = "publicCategories", allEntries = true)
    public void deleteCategory(Long id) {
        categoryRepository.deleteById(id);
    }
}
