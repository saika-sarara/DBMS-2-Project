package com.learnova.review.service;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.learnova.common.exception.DatabaseException;
import com.learnova.common.exception.ResourceNotFoundException;
import com.learnova.enrollment.support.CurrentUserResolver;
import com.learnova.review.dto.ReviewCreateRequest;
import com.learnova.review.dto.ReviewCreateResponse;
import com.learnova.review.dto.ReviewStateResponse;
import com.learnova.review.repository.ReviewRepository;
import org.springframework.dao.DataAccessException;
import org.springframework.stereotype.Service;

import java.util.List;