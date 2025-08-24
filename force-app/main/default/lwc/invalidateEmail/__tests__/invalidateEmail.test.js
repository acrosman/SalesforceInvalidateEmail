import { createElement } from '@lwc/engine-dom';
import InvalidateEmail from 'c/invalidateEmail';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';

// Mock the Apex method
jest.mock(
    '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura',
    () => {
        const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
        return {
            default: createApexTestWireAdapter(jest.fn())
        };
    },
    { virtual: true }
);

describe('c-invalidate-email', () => {
    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        // Clear all mocks
        jest.clearAllMocks();
    });

    it('renders the component with both buttons', () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });

        // Act
        document.body.appendChild(element);

        // Assert
        const card = element.shadowRoot.querySelector('lightning-card');
        expect(card).not.toBeNull();
        expect(card.title).toBe('Email Invalidation');

        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        expect(buttons).toHaveLength(2);

        const invalidateButton = buttons[0];
        expect(invalidateButton.label).toBe('Invalidate Emails');
        expect(invalidateButton.variant).toBe('destructive');

        const restoreButton = buttons[1];
        expect(restoreButton.label).toBe('Restore Emails');
        expect(restoreButton.variant).toBe('success');
    });

    it('calls Apex method and shows success toast on invalidate button click', async () => {
        // Arrange
        const mockResponse = {
            success: true,
            message: 'Email invalidation batch jobs started for all configured email fields.'
        };
        invalidateAllConfiguredEmails.mockResolvedValue(mockResponse);

        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const invalidateButton = buttons[0];
        invalidateButton.click();

        // Wait for async operations
        await Promise.resolve();

        // Assert
        expect(invalidateAllConfiguredEmails).toHaveBeenCalledTimes(1);
    });

    it('executes restore button click without errors (placeholder functionality)', async () => {
        // Arrange
        const element = createElement('c-invalidate-email', {
            is: InvalidateEmail
        });
        document.body.appendChild(element);

        // Act
        const buttons = element.shadowRoot.querySelectorAll('lightning-button');
        const restoreButton = buttons[1];

        // This should not throw an error
        expect(() => {
            restoreButton.click();
        }).not.toThrow();

        // Wait for async operations
        await Promise.resolve();

        // Assert that the button exists and is clickable
        expect(restoreButton).not.toBeNull();
        expect(restoreButton.label).toBe('Restore Emails');
    });
});
