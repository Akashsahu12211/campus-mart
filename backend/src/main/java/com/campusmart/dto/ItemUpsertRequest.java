package com.campusmart.dto;

import com.campusmart.model.Item;
import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

public class ItemUpsertRequest {

    @NotBlank(message = "Title is required")
    @Size(max = 140, message = "Title must be 140 characters or shorter")
    private String title;

    @Size(max = 4000, message = "Description must be 4000 characters or shorter")
    private String description;

    @NotNull(message = "Price is required")
    @DecimalMin(value = "0.0", inclusive = true, message = "Price must be zero or higher")
    private BigDecimal price;

    private Long categoryId;

    @Valid
    private CategoryReference category;

    @NotNull(message = "Condition is required")
    private Item.ItemCondition condition;

    private Boolean negotiable = false;
    private Item.ListingType listingType;
    private Boolean donation = false;
    private Boolean bundle = false;

    @Min(value = 2, message = "Bundle size should be at least 2")
    private Integer bundleSize;

    @Size(max = 20, message = "A maximum of 20 images is allowed")
    private List<@NotBlank(message = "Image reference cannot be blank") @Size(max = 2048, message = "Image reference is too long") String> imageUrls = new ArrayList<>();

    @Size(max = 120, message = "Author name is too long")
    private String bookAuthor;

    @Size(max = 80, message = "Book edition is too long")
    private String bookEdition;

    @Size(max = 120, message = "Academic subject is too long")
    private String academicSubject;

    @Size(max = 120, message = "Academic course is too long")
    private String academicCourse;

    @Size(max = 120, message = "Academic level is too long")
    private String academicLevel;

    @Size(max = 120, message = "Board or university is too long")
    private String boardOrUniversity;

    @Size(max = 120, message = "Publisher is too long")
    private String publisher;

    @Size(max = 40, message = "ISBN is too long")
    private String isbn;

    public Long resolveCategoryId() {
        if (categoryId != null) {
            return categoryId;
        }
        return category != null ? category.getId() : null;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public BigDecimal getPrice() {
        return price;
    }

    public void setPrice(BigDecimal price) {
        this.price = price;
    }

    public Long getCategoryId() {
        return categoryId;
    }

    public void setCategoryId(Long categoryId) {
        this.categoryId = categoryId;
    }

    public CategoryReference getCategory() {
        return category;
    }

    public void setCategory(CategoryReference category) {
        this.category = category;
    }

    public Item.ItemCondition getCondition() {
        return condition;
    }

    public void setCondition(Item.ItemCondition condition) {
        this.condition = condition;
    }

    public Boolean getNegotiable() {
        return negotiable;
    }

    public void setNegotiable(Boolean negotiable) {
        this.negotiable = negotiable;
    }

    public Item.ListingType getListingType() {
        return listingType;
    }

    public void setListingType(Item.ListingType listingType) {
        this.listingType = listingType;
    }

    public Boolean getDonation() {
        return donation;
    }

    public void setDonation(Boolean donation) {
        this.donation = donation;
    }

    public Boolean getBundle() {
        return bundle;
    }

    public void setBundle(Boolean bundle) {
        this.bundle = bundle;
    }

    public Integer getBundleSize() {
        return bundleSize;
    }

    public void setBundleSize(Integer bundleSize) {
        this.bundleSize = bundleSize;
    }

    public List<String> getImageUrls() {
        return imageUrls;
    }

    public void setImageUrls(List<String> imageUrls) {
        this.imageUrls = imageUrls;
    }

    public String getBookAuthor() {
        return bookAuthor;
    }

    public void setBookAuthor(String bookAuthor) {
        this.bookAuthor = bookAuthor;
    }

    public String getBookEdition() {
        return bookEdition;
    }

    public void setBookEdition(String bookEdition) {
        this.bookEdition = bookEdition;
    }

    public String getAcademicSubject() {
        return academicSubject;
    }

    public void setAcademicSubject(String academicSubject) {
        this.academicSubject = academicSubject;
    }

    public String getAcademicCourse() {
        return academicCourse;
    }

    public void setAcademicCourse(String academicCourse) {
        this.academicCourse = academicCourse;
    }

    public String getAcademicLevel() {
        return academicLevel;
    }

    public void setAcademicLevel(String academicLevel) {
        this.academicLevel = academicLevel;
    }

    public String getBoardOrUniversity() {
        return boardOrUniversity;
    }

    public void setBoardOrUniversity(String boardOrUniversity) {
        this.boardOrUniversity = boardOrUniversity;
    }

    public String getPublisher() {
        return publisher;
    }

    public void setPublisher(String publisher) {
        this.publisher = publisher;
    }

    public String getIsbn() {
        return isbn;
    }

    public void setIsbn(String isbn) {
        this.isbn = isbn;
    }

    public static class CategoryReference {
        @NotNull(message = "Category is required")
        private Long id;

        public Long getId() {
            return id;
        }

        public void setId(Long id) {
            this.id = id;
        }
    }
}
