import mnist_classifier
import mnist_dataloader
import torch
from tqdm import tqdm


def main():
    # Get device
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

    train_loader, test_loader = mnist_dataloader.get_dataloader()
    # Get a batch of training data and print the shape, dtype and device
    for x_batch, y_batch in train_loader:
        print("x_batch.shape:", x_batch.shape)
        print("x_batch.dtype:", x_batch.dtype)
        print("x_batch.device:", x_batch.device)
        print("y_batch.shape:", y_batch.shape)
        print("y_batch.dtype:", y_batch.dtype)
        print("y_batch.device:", y_batch.device)
        break

    model = mnist_classifier.MnistClassifier()
    print(model)

    # Move the model to the device
    model = model.to(device)

    # Define the loss function using that the model outputs logits
    loss_fn = torch.nn.CrossEntropyLoss()

    # Define the optimizer
    optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

    # Train the model
    for t in range(10):
        # Training pass
        iteration = 0
        for x_batch, y_batch in tqdm(train_loader, desc=f"Epoch {t}", total=len(train_loader)):
            # Move data to the device
            x_batch = x_batch.to(device)
            y_batch = y_batch.to(device)

            # Compute prediction and loss
            y_pred = model(x_batch)
            loss = loss_fn(y_pred, y_batch)

            # Zero gradients, perform a backward pass, and update
            optimizer.zero_grad()
            loss.backward()
            optimizer.step()

            if iteration > 40:
                break
            iteration += 1

        # Compute the accuracy
        correct = 0
        total = 0
        with torch.no_grad():
            for x_batch, y_batch in test_loader:
                x_batch = x_batch.to(device)
                y_batch = y_batch.to(device)
                y_pred = model(x_batch)
                _, predicted = torch.max(y_pred, 1)
                total += y_batch.size(0)
                correct += (predicted == y_batch).sum().item()

        print(f"Epoch {t}: Accuracy: {correct / total}")

    print("Done!")


if __name__ == "__main__":
    main()
