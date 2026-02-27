// Star rating functionality
function initStarRating() {
    const stars = document.querySelectorAll('.star-rating .star');
    const reviewText = document.getElementById('review-text');
    const submitReviewBtn = document.getElementById('submit-review');
    
    if (!stars.length) return;
    
    let selectedRating = 0;
    
    // Handle star clicks
    stars.forEach(star => {
        star.addEventListener('click', function() {
            selectedRating = parseInt(this.getAttribute('data-rating'));
            updateStarRating(selectedRating);
        });
        
        // Handle hover effect
        star.addEventListener('mouseover', function() {
            const rating = parseInt(this.getAttribute('data-rating'));
            updateStarRating(rating, true);
        });
        
        star.addEventListener('mouseout', function() {
            updateStarRating(selectedRating);
        });
    });
    
    // Update star display
    function updateStarRating(rating, isHover = false) {
        stars.forEach(star => {
            const starRating = parseInt(star.getAttribute('data-rating'));
            if (starRating <= rating) {
                star.classList.add('filled');
            } else {
                star.classList.remove('filled');
            }
        });
        
        // Show submit button if rating is selected
        if (submitReviewBtn) {
            if (rating > 0) {
                submitReviewBtn.style.display = 'block';
            } else if (!isHover) {
                submitReviewBtn.style.display = 'none';
            }
        }
    }
    
    // Handle review text input
    if (reviewText) {
        reviewText.addEventListener('input', function() {
            if (submitReviewBtn) {
                if (this.value.trim() !== '' && selectedRating > 0) {
                    submitReviewBtn.style.display = 'block';
                } else if (selectedRating === 0) {
                    submitReviewBtn.style.display = 'none';
                }
            }
        });
    }
    
    // Handle submit review button
    if (submitReviewBtn) {
        submitReviewBtn.addEventListener('click', function() {
            if (selectedRating > 0) {
                alert('Review submitted successfully!');
                // In a real app, you would send this data to a server
            } else {
                alert('Please select a rating before submitting.');
            }
        });
    }
}

// Modal functionality
function initModals() {
    const modals = document.querySelectorAll('.modal');
    const modalCloseButtons = document.querySelectorAll('.modal-close');
    const modalTriggers = document.querySelectorAll('[data-modal]');
    
    // Hide all modals by default
    modals.forEach(modal => {
        modal.classList.remove('show');
    });
    
    // Close modal when clicking on close button
    modalCloseButtons.forEach(button => {
        button.addEventListener('click', function() {
            const modal = this.closest('.modal');
            if (modal) {
                modal.classList.remove('show');
            }
        });
    });
    
    // Close modal when clicking outside content
    modals.forEach(modal => {
        modal.addEventListener('click', function(e) {
            if (e.target === this) {
                this.classList.remove('show');
            }
        });
    });
    
    // Open modal when trigger is clicked
    modalTriggers.forEach(trigger => {
        trigger.addEventListener('click', function() {
            const modalId = this.getAttribute('data-modal');
            const modal = document.getElementById(modalId);
            if (modal) {
                modal.classList.add('show');
            }
        });
    });
    
    // Handle specific modal buttons
    const deleteAccountYesBtn = document.querySelector('#delete-account-modal .btn-warning');
    if (deleteAccountYesBtn) {
        deleteAccountYesBtn.addEventListener('click', function() {
            const modal = this.closest('.modal');
            if (modal) {
                modal.classList.remove('show');
                alert('Account deleted successfully!');
                // In a real app, you would delete the account on the server
                // and redirect to the login page
                localStorage.removeItem('user');
                window.location.href = '../auth/signin.html';
            }
        });
    }
    
    const changePasswordForm = document.querySelector('#change-password-modal form');
    if (changePasswordForm) {
        changePasswordForm.addEventListener('submit', function(e) {
            e.preventDefault();
            const oldPassword = document.getElementById('old-password').value;
            const newPassword = document.getElementById('new-password').value;
            
            // In a real app, you would verify the old password and update it on the server
            // For now, we'll just simulate success
            alert('Password changed successfully!');
            
            // Close the modal
            const modal = this.closest('.modal');
            if (modal) {
                modal.classList.remove('show');
            }
        });
    }
}

// Profile page specific functionality
function initProfilePage() {
    const changePasswordBtn = document.getElementById('change-password');
    const deleteAccountBtn = document.getElementById('delete-account');
    const signOutBtn = document.getElementById('sign-out');
    
    if (changePasswordBtn) {
        changePasswordBtn.addEventListener('click', function() {
            const modal = document.getElementById('change-password-modal');
            if (modal) {
                modal.classList.add('show');
            }
        });
    }
    
    if (deleteAccountBtn) {
        deleteAccountBtn.addEventListener('click', function() {
            const modal = document.getElementById('delete-account-modal');
            if (modal) {
                modal.classList.add('show');
            }
        });
    }
    
    if (signOutBtn) {
        signOutBtn.addEventListener('click', function() {
            // In a real app, this would redirect to the login page
            localStorage.removeItem('user');
            alert('You have been signed out.');
            window.location.href = '../auth/signin.html';
        });
    }
}

// Initialize all functionality when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    initStarRating();
    initModals();
    initProfilePage();
});

// Export functions for module usage
export { initStarRating, initModals, initProfilePage };